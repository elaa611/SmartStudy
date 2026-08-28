import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ------------------------------------------------------------
    // 1) Lire les paramètres envoyés par Flutter (noms alignés avec
    //    generate_quiz_screen.dart : subject_id, document_ids,
    //    nb_questions, difficulty, subject_name)
    // ------------------------------------------------------------
    const { subject_id, document_ids, nb_questions, difficulty, subject_name } =
      await req.json();

    const normalizedDifficulty = String(difficulty).toLowerCase();
    if (!["easy", "medium", "hard"].includes(normalizedDifficulty)) {
      return new Response(
        JSON.stringify({
          error: `Difficulté invalide: ${difficulty}`,
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
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
    //    (c'est ce qui manquait : sans ça, le quiz ne se basait pas
    //    sur les cours de l'utilisateur)
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

    const MAX_CHARS = 40000;
    const texteCombine = documents
      .map((d) => `--- Cours: ${d.file_name} ---\n${d.extracted_text ?? ""}`)
      .join("\n\n")
      .slice(0, MAX_CHARS);

    // ------------------------------------------------------------
    // 3) Créer le quiz en statut "generating"
    // ------------------------------------------------------------
    const { data: quiz, error: quizError } = await supabaseClient
      .from("quizzes")
      .insert({
        user_id: user.id,
        subject_id: subject_id,
        title: `Quiz - ${subject_name}`,
        difficulty: normalizedDifficulty,
        nb_questions,
        status: "generating",
      })
      .select()
      .single();

    if (quizError) throw quizError;

    // ------------------------------------------------------------
    // 4) Appeler Gemini pour générer les questions
    // ------------------------------------------------------------

    const prompt = `You are an educational quiz generator.

Based ONLY on the course content provided below, generate exactly ${nb_questions} multiple-choice questions.

IMPORTANT LANGUAGE RULE:
- First, identify the primary language used in the course content.
- Generate the entire quiz in the SAME primary language as the course content.
- The questions MUST be written in the primary language of the course content.
- All 4 answer options MUST be written in the primary language of the course content.
- The explanations MUST be written in the primary language of the course content.
- Do NOT automatically translate the course content into English.
- Do NOT change the language of the quiz unless explicitly requested.
- If the course content is in French, generate the quiz entirely in French.
- If the course content is in English, generate the quiz entirely in English.
- If the course content is in Arabic, generate the quiz entirely in Arabic.
- If the course content is in another language, generate the quiz in that language.
- If the course contains multiple languages, use the language that is dominant in the course content.
- Keep technical terms, scientific terms, programming keywords, formulas, and proper names exactly as they appear in the course when appropriate.

Quiz difficulty: "${normalizedDifficulty}"
Subject: "${subject_name}"

Rules:
- Generate exactly ${nb_questions} questions.
- Each question must have exactly 4 options.
- correctIndex must be a number between 0 and 3.
- Questions must be based ONLY on the course content.
- Each question must have an explanation.
- The explanation must be written in the same language as the question and answer options.
- Avoid duplicate or nearly identical questions.
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
              parts: [
                {
                  text: prompt,
                },
              ],
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

    if (!Array.isArray(questions)) {
      throw new Error(
        'La réponse Gemini ne contient pas de tableau "questions"',
      );
    }

    // ------------------------------------------------------------
    // 5) Insérer les questions générées
    //    IMPORTANT : la colonne s'appelle "correct_index" (et non
    //    "correct_answer_index") car c'est ce que lit
    //    QuizQuestion.fromMap dans quiz_play_screen.dart
    // ------------------------------------------------------------
    const questionsToInsert = questions.map((q: any, index: number) => ({
      quiz_id: quiz.id,
      question_text: q.question,
      options: q.options,
      correct_index: q.correctIndex,
      explanation: q.explanation,
      order_index: index,
    }));

    const { error: insertError } = await supabaseClient
      .from("quiz_questions")
      .insert(questionsToInsert);

    if (insertError) throw insertError;

    // ------------------------------------------------------------
    // 6) Tracer quels documents ont servi (table de liaison)
    // ------------------------------------------------------------
    const liaisons = document_ids.map((docId: string) => ({
      quiz_id: quiz.id,
      document_id: docId,
    }));

    const { error: linkError } = await supabaseClient
      .from("quiz_documents")
      .insert(liaisons);

    if (linkError) {
      throw linkError;
    }

    // ------------------------------------------------------------
    // 7) Marquer le quiz comme prêt
    // ------------------------------------------------------------
    const { error: updateError } = await supabaseClient
      .from("quizzes")
      .update({ status: "ready" })
      .eq("id", quiz.id);

    if (updateError) {
      throw updateError;
    }

    // ------------------------------------------------------------
    // 8) Répondre à Flutter avec l'id du quiz créé
    //    (quiz_id en snake_case, comme le lit generate_quiz_screen.dart :
    //    data['quiz_id'])
    // ------------------------------------------------------------
    return new Response(
      JSON.stringify({ quiz_id: quiz.id }),
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
