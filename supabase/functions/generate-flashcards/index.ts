import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Même limite que generate-quiz : on ne renvoie pas des dizaines de milliers
// de caractères de cours dans le prompt Gemini.
const MAX_PROMPT_CHARS = 40_000

const GEMINI_MODEL = 'gemini-3.6-flash'

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
    // ------------------------------------------------------------
    // 1) Client Supabase "au nom de l'utilisateur" (respecte la RLS)
    // ------------------------------------------------------------
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

    // ------------------------------------------------------------
    // 2) Lire les paramètres envoyés par Flutter (GenerateFlashcardsScreen)
    // ------------------------------------------------------------
    const body = await req.json()
    const subjectId = body.subject_id as number | undefined
    const documentIds = body.document_ids as string[] | undefined
    const nbCards = (body.nb_cards as number | undefined) ?? 20
    const subjectName = (body.subject_name as string | undefined) ?? 'Course'

    if (!subjectId || !documentIds || documentIds.length === 0) {
      return new Response(JSON.stringify({ error: 'Paramètres manquants (subject_id, document_ids)' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ------------------------------------------------------------
    // 3) Récupérer le texte déjà extrait des documents choisis
    //    (la RLS garantit que ce sont bien SES documents ; on double
    //    vérifie quand même avec .eq('user_id', user.id))
    // ------------------------------------------------------------
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
        JSON.stringify({ error: "Aucun texte exploitable dans les documents sélectionnés" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ------------------------------------------------------------
    // 4) Appeler Gemini pour générer les flashcards en JSON structuré
    // ------------------------------------------------------------
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!
    const prompt =
      `Tu es un assistant pédagogique. À partir du contenu de cours ci-dessous ` +
      `(matière : "${subjectName}"), génère exactement ${nbCards} flashcards de révision.\n\n` +
      `Chaque flashcard doit avoir :\n` +
      `- "term" : un terme, concept ou question courte (recto de la carte)\n` +
      `- "definition" : la définition, réponse ou explication (verso de la carte)\n\n` +
      `Règles :\n` +
      `- Couvre les notions les plus importantes du texte, sans doublons.\n` +
      `- Reste concis : "term" fait moins de 10 mots, "definition" moins de 40 mots.\n` +
      `- Réponds uniquement dans la langue du texte source.\n\n` +
      `Contenu du cours :\n"""\n${combinedText}\n"""`

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
      throw new Error("Réponse Gemini vide ou mal formée")
    }

    const cards = JSON.parse(rawJson) as { term: string; definition: string }[]

    if (!Array.isArray(cards) || cards.length === 0) {
      throw new Error("Gemini n'a renvoyé aucune flashcard exploitable")
    }

    // ------------------------------------------------------------
    // 5) Créer le set de flashcards + insérer chaque carte
    //    (tables à créer si elles n'existent pas encore, voir schéma
    //    plus bas en commentaire)
    // ------------------------------------------------------------
    const { data: flashcardSet, error: setError } = await supabase
      .from('flashcard_sets')
      .insert({
        subject_id: subjectId,
        user_id: user.id,
        title: `${subjectName} — Flashcards`,
      })
      .select('id')
      .single()

    if (setError || !flashcardSet) {
      throw new Error(`Impossible de créer le set de flashcards : ${setError?.message}`)
    }

    const rows = cards.map((c, index) => ({
      set_id: flashcardSet.id,
      term: c.term,
      definition: c.definition,
      order_index: index,
    }))

    const { error: insertError } = await supabase.from('flashcards').insert(rows)
    if (insertError) throw insertError

    return new Response(
      JSON.stringify({ flashcard_set_id: flashcardSet.id, cards_count: rows.length }),
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