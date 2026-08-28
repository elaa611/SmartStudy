import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_CHARS = 40000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ------------------------------------------------------------
    // 1) Lire les paramètres envoyés par Flutter (noms alignés avec
    //    generate_qa_screen.dart : subject_id, document_ids,
    //    nb_questions, subject_name)
    // ------------------------------------------------------------
    const { subject_id, document_ids, nb_questions, subject_name } =
      await req.json();

    if (!document_ids || document_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: "Aucun document sélectionné" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Client Supabase avec le JWT de l'utilisateur (pour connaître son user_id via RLS)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) throw new Error("Non authentifié");

    // ------------------------------------------------------------
    // 2) Récupérer le texte extrait des documents sélectionnés
    // ------------------------------------------------------------
    const { data: documents, error: docsError } = await supabaseClient
      .from("documents")
      .select("id, file_name, extracted_text")
      .in("id", document_ids)
      .eq("user_id", user.id);

    if (docsError || !documents || documents.length === 0) {
      return new Response(
        JSON.stringify({ error: "Documents introuvables" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const texteCombine = documents
      .map((d) => `--- Cours: ${d.file_name} ---\n${d.extracted_text ?? ""}`)
      .join("\n\n")
      .slice(0, MAX_CHARS);

    if (!texteCombine.trim()) {
      return new Response(
        JSON.stringify({ error: "Aucun texte exploitable dans les documents sélectionnés" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ------------------------------------------------------------
    // 3) Créer le set de Q/A en statut "generating"
    // ------------------------------------------------------------
    const { data: qaSet, error: setError } = await supabaseClient
      .from("qa_sets")
      .insert({
        user_id: user.id,
        subject_id: subject_id,
        title: `Q&A - ${subject_name}`,
        nb_questions,
        status: "generating",
      })
      .select()
      .single();

    if (setError) throw setError;

    // ------------------------------------------------------------
    // 4) Appeler Gemini pour générer les questions/réponses
    // ------------------------------------------------------------
    const prompt = `You are an educational assistant generating open-ended review questions.

Based ONLY on the course content provided below, generate exactly ${nb_questions} question/answer pairs
that help a student test their understanding (not multiple choice — open, short-answer questions).

IMPORTANT LANGUAGE RULE:
- First, identify the primary language used in the course content.
- Generate the entire Q&A set in the SAME primary language as the course content.
- Do NOT automatically translate the course content into English.
- If the course content is in French, generate everything in French. If in English, in English.
  If in Arabic, in Arabic. If another language, use that language.
- Keep technical terms, scientific terms, programming keywords, formulas, and proper names exactly
  as they appear in the course when appropriate.

Subject: "${subject_name}"

Rules:
- Generate exactly ${nb_questions} question/answer pairs.
- Questions must be based ONLY on the course content, testing understanding of key concepts.
- Each answer should be clear and concise (1 to 3 sentences), directly supported by the course content.
- Avoid duplicate or nearly identical questions.
- Do NOT invent information that is not present in the course content.
- Do NOT use external knowledge.
- Return ONLY valid JSON.
- Do not use Markdown.
- Do not add any text before or after the JSON.

Required format:
{
  "questions": [
    {
      "question": "Question in the same language as the course content",
      "answer": "Answer in the same language as the course content"
    }
  ]
}
Course content:
${texteCombine}`;

    const geminiResponse = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")!,
        },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            maxOutputTokens: 4000,
            responseMimeType: "application/json",
          },
        }),
      },
    );

    const geminiData = await geminiResponse.json();

    if (!geminiResponse.ok) {
      throw new Error(
        `Gemini API error ${geminiResponse.status}: ${JSON.stringify(geminiData)}`,
      );
    }

    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      throw new Error(`Gemini n'a retourné aucun texte: ${JSON.stringify(geminiData)}`);
    }

    const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "").trim();
    const parsed = JSON.parse(cleanJson);
    const questions = parsed.questions;

    if (!Array.isArray(questions)) {
      throw new Error('La réponse Gemini ne contient pas de tableau "questions"');
    }

    // ------------------------------------------------------------
    // 5) Insérer les questions/réponses générées
    // ------------------------------------------------------------
    const itemsToInsert = questions.map((q: any, index: number) => ({
      set_id: qaSet.id,
      question: q.question,
      answer: q.answer,
      order_index: index,
    }));

    const { error: insertError } = await supabaseClient
      .from("qa_items")
      .insert(itemsToInsert);

    if (insertError) throw insertError;

    // ------------------------------------------------------------
    // 6) Tracer quels documents ont servi (table de liaison)
    // ------------------------------------------------------------
    const liaisons = document_ids.map((docId: string) => ({
      qa_set_id: qaSet.id,
      document_id: docId,
    }));

    const { error: linkError } = await supabaseClient
      .from("qa_documents")
      .insert(liaisons);

    if (linkError) throw linkError;

    // ------------------------------------------------------------
    // 7) Marquer le set comme prêt
    // ------------------------------------------------------------
    const { error: updateError } = await supabaseClient
      .from("qa_sets")
      .update({ status: "ready" })
      .eq("id", qaSet.id);

    if (updateError) throw updateError;

    // ------------------------------------------------------------
    // 8) Répondre à Flutter avec l'id du set créé
    //    (qa_set_id en snake_case, comme le lit generate_qa_screen.dart :
    //    data['qa_set_id'])
    // ------------------------------------------------------------
    return new Response(
      JSON.stringify({ qa_set_id: qaSet.id }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});