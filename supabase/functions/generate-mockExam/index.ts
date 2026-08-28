import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_PROMPT_CHARS = 40_000;

const GEMINI_MODEL = "gemini-3.5-flash-lite";

interface DocumentRow {
  id: string;
  file_name: string;
  extracted_text: string | null;
  extraction_status: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      subject_id,
      document_ids,
      nb_questions,
      duration_minutes,
      subject_name,
    } = await req.json();

    if (!subject_id) {
      return new Response(
        JSON.stringify({ error: "Paramètre manquant : subject_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!document_ids || document_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: "Aucun document sélectionné" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const nbQuestions = Number(nb_questions) > 0 ? Number(nb_questions) : 20;
    const dureeMinutes = Number(duration_minutes) > 0
      ? Number(duration_minutes)
      : 30;

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
    if (!user) {
      return new Response(JSON.stringify({ error: "Non authentifié" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2) Récupérer le texte extrait des documents sélectionnés
    const { data: documents, error: docsError } = await supabaseClient
      .from("documents")
      .select("id, file_name, extracted_text, extraction_status")
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

    const texteCombine = (documents as DocumentRow[])
      .filter((d) => d.extraction_status === "completed" && d.extracted_text)
      .map((d) => `--- Cours: ${d.file_name} ---\n${d.extracted_text}`)
      .join("\n\n")
      .slice(0, MAX_PROMPT_CHARS);

    if (!texteCombine) {
      return new Response(
        JSON.stringify({
          error: "Aucun texte exploitable dans les documents sélectionnés",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3) Créer l'examen blanc en statut "generating"
    const { data: exam, error: examError } = await supabaseClient
      .from("mock_exams")
      .insert({
        user_id: user.id,
        subject_id: subject_id,
        title: `Mock Exam - ${subject_name}`,
        nb_questions: nbQuestions,
        duration_minutes: dureeMinutes,
        status: "generating",
      })
      .select()
      .single();

    if (examError) throw examError;

    // 4) Appeler Gemini pour générer les questions
    const prompt = `You are an educational exam generator.

Based ONLY on the course content provided below, generate exactly ${nbQuestions} multiple-choice questions that simulate a REAL exam covering the material.

IMPORTANT LANGUAGE RULE:
- First, identify the primary language used in the course content.
- Generate the entire exam in the SAME primary language as the course content.
- The questions MUST be written in the primary language of the course content.
- All 4 answer options MUST be written in the primary language of the course content.
- The explanations MUST be written in the primary language of the course content.
- Do NOT automatically translate the course content into English.
- Do NOT change the language of the exam unless explicitly requested.
- If the course content is in French, generate the exam entirely in French.
- If the course content is in English, generate the exam entirely in English.
- If the course content is in Arabic, generate the exam entirely in Arabic.
- If the course content is in another language, generate the exam in that language.
- If the course contains multiple languages, use the language that is dominant in the course content.
- Keep technical terms, scientific terms, programming keywords, formulas, and proper names exactly as they appear in the course when appropriate.

Subject: "${subject_name}"
Exam duration: ${dureeMinutes} minutes

Rules:
- Generate exactly ${nbQuestions} questions.
- Mix difficulty levels realistically: roughly 30% easy, 40% medium, 30% hard, spread throughout the exam (do not group by difficulty).
- Each question must have exactly 4 options.
- correctIndex must be a number between 0 and 3.
- Questions must be based ONLY on the course content.
- Each question must have a short explanation of the correct answer.
- The explanation must be written in the same language as the question and answer options.
- Cover the course content as broadly as possible, avoid duplicate or nearly identical questions.
- The correct answer must be clearly supported by the course content.
- Do NOT invent information that is not present in the course content.
- Do NOT use external knowledge.
- Do NOT add information just to make a question more complete.
- Preserve the meaning of the original course content.
- Return ONLY valid JSON.
- Do not use Markdown.
- Do not add any text before or after the JSON.

Required format:
{
  "questions": [
    {
      "question": "Question in the same language as the course content",
      "options": [
        "Option A",
        "Option B",
        "Option C",
        "Option D"
      ],
      "correctIndex": 0,
      "explanation": "Explanation in the same language as the course content"
    }
  ]
}
Course content:
${texteCombine}`;

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
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
            maxOutputTokens: 8000,
            responseMimeType: "application/json",
          },
        }),
      },
    );

    const geminiData = await geminiResponse.json();

    if (!geminiResponse.ok) {
      throw new Error(
        `Gemini API error ${geminiResponse.status}: ${
          JSON.stringify(geminiData)
        }`,
      );
    }

    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      throw new Error(
        `Gemini n'a retourné aucun texte: ${JSON.stringify(geminiData)}`,
      );
    }

    const cleanJson = rawText
      .replace(/```json/g, "")
      .replace(/```/g, "")
      .trim();

    const parsed = JSON.parse(cleanJson);

    const questions = parsed.questions;

    if (!Array.isArray(questions) || questions.length === 0) {
      throw new Error(
        'La réponse Gemini ne contient pas de tableau "questions"',
      );
    }

    // 5) Insérer les questions générées
    const questionsToInsert = questions.map((q: any, index: number) => ({
      exam_id: exam.id,
      question_text: q.question,
      options: q.options,
      correct_index: q.correctIndex,
      explanation: q.explanation,
      order_index: index,
    }));

    const { error: insertError } = await supabaseClient
      .from("mock_exam_questions")
      .insert(questionsToInsert);

    if (insertError) throw insertError;

    // 6) Tracer quels documents ont servi (table de liaison)
    const liaisons = document_ids.map((docId: string) => ({
      exam_id: exam.id,
      document_id: docId,
    }));

    const { error: linkError } = await supabaseClient
      .from("mock_exam_documents")
      .insert(liaisons);

    if (linkError) throw linkError;

    // 7) Marquer l'examen comme prêt
    const { error: updateError } = await supabaseClient
      .from("mock_exams")
      .update({ status: "ready" })
      .eq("id", exam.id);

    if (updateError) throw updateError;

    // 8) Répondre à Flutter avec l'id de l'examen créé
    return new Response(
      JSON.stringify({ exam_id: exam.id }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});