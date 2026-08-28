import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Même limite que generate-quiz / generate-flashcards : on ne renvoie pas des
// dizaines de milliers de caractères de cours dans le prompt Gemini.
const MAX_PROMPT_CHARS = 40_000

const GEMINI_MODEL = 'gemini-3.5-flash'

interface DocumentRow {
  id: string
  file_name: string
  extracted_text: string | null
  extraction_status: string
}




Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1) Client Supabase "au nom de l'utilisateur" (respecte la RLS)
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      return new Response(JSON.stringify({ error: 'Non authentifié' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2) Lire les paramètres envoyés par Flutter (GenerateSummaryScreen)
    const body = await req.json()
    const subjectId = body.subject_id as number | undefined
    const documentIds = body.document_ids as string[] | undefined
    const subjectName = (body.subject_name as string | undefined) ?? 'Course'

    if (!subjectId || !documentIds || documentIds.length === 0) {
      return new Response(JSON.stringify({ error: 'Paramètres manquants (subject_id, document_ids)' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3) Récupérer le texte déjà extrait des documents choisis
    const { data: documents, error: docsError } = await supabase
      .from('documents')
      .select('id, file_name, extracted_text, extraction_status')
      .in('id', documentIds)
      .eq('user_id', user.id)

    if (docsError || !documents || documents.length === 0) {
      return new Response(JSON.stringify({ error: 'Documents introuvables' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const combinedText = (documents as DocumentRow[])
      .filter((d) => d.extraction_status === 'completed' && d.extracted_text)
      .map((d) => `## ${d.file_name}\n${d.extracted_text}`)
      .join('\n\n')
      .slice(0, MAX_PROMPT_CHARS)

    if (!combinedText) {
      return new Response(
        JSON.stringify({ error: 'Aucun texte exploitable dans les documents sélectionnés' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // 4) Appeler Gemini pour générer le résumé structuré
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!
    const prompt =
      `You are an educational assistant. Based ONLY on the course content below ` +
      `(subject: "${subjectName}"), produce a structured study summary.\n\n` +
      `LANGUAGE RULE: identify the primary language of the course content and write ` +
      `the entire summary in that same language. Keep technical terms, formulas and ` +
      `proper names exactly as they appear in the source.\n\n` +
      `Return a JSON object with:\n` +
      `- "title": a short descriptive title for this summary (a few words)\n` +
      `- "key_ideas": an array of 4 to 8 short bullet-point strings covering the most ` +
      `important concepts, ranked by importance, no duplicates\n` +
      `- "definitions": an array of objects {"term", "definition"} for the 3 to 8 most ` +
      `important terms or concepts to know, each definition under 30 words\n` +
      `- "formulas": an array of important formulas or equations found in the content, ` +
      `as plain strings (e.g. "E = hf"). Return an EMPTY array if the subject has no formulas.\n\n` +
      `Rules:\n` +
      `- Base everything ONLY on the provided content, do not invent information.\n` +
      `- Return ONLY valid JSON, no markdown, no text before or after.\n\n` +
      `Course content:\n"""\n${combinedText}\n"""`

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                title: { type: 'STRING' },
                key_ideas: { type: 'ARRAY', items: { type: 'STRING' } },
                definitions: {
                  type: 'ARRAY',
                  items: {
                    type: 'OBJECT',
                    properties: {
                      term: { type: 'STRING' },
                      definition: { type: 'STRING' },
                    },
                    required: ['term', 'definition'],
                  },
                },
                formulas: { type: 'ARRAY', items: { type: 'STRING' } },
              },
              required: ['title', 'key_ideas', 'definitions', 'formulas'],
            },
          },
        }),
      },
    )

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text()
      throw new Error(`Erreur Gemini (${geminiResponse.status}) : ${errText}`)
    }

    const geminiData = await geminiResponse.json()
    const rawJson = geminiData.candidates?.[0]?.content?.parts?.[0]?.text

    if (!rawJson) {
      throw new Error('Réponse Gemini vide ou mal formée')
    }

    const parsed = JSON.parse(rawJson) as {
      title: string
      key_ideas: string[]
      definitions: { term: string; definition: string }[]
      formulas: string[]
    }

    if (!parsed.title || !Array.isArray(parsed.key_ideas)) {
      throw new Error("Gemini n'a renvoyé aucun résumé exploitable")
    }

    // 5) Sauvegarder le résumé (table `summaries`, voir schema_additions.sql)
    const { data: summary, error: insertError } = await supabase
      .from('summaries')
      .insert({
        subject_id: subjectId,
        user_id: user.id,
        title: parsed.title,
        key_ideas: parsed.key_ideas,
        definitions: parsed.definitions ?? [],
        formulas: parsed.formulas ?? [],
        document_ids: documentIds,
      })
      .select('id')
      .single()

    if (insertError || !summary) {
      throw new Error(`Impossible d'enregistrer le résumé : ${insertError?.message}`)
    }

    return new Response(
      JSON.stringify({ summary_id: summary.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})