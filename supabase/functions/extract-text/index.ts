import { createClient } from '@supabase/supabase-js'
import { getDocumentProxy, extractText as extractPdfText } from 'unpdf'
import mammoth from 'mammoth'
import JSZip from 'jszip'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Taille max de texte qu'on garde en base, pour ne pas exploser la colonne
// (generate-quiz tronque de toute façon à 40 000 caractères)
const MAX_STORED_CHARS = 200_000

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // On a besoin du document_id même si tout plante ensuite, pour pouvoir
  // marquer le document en "failed" plutôt que de le laisser bloqué en "pending"
  let documentId: string | undefined

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
    // 2) Lire le paramètre envoyé par Flutter
    // ------------------------------------------------------------
    const body = await req.json()
    documentId = body.document_id as string | undefined

    if (!documentId) {
      return new Response(JSON.stringify({ error: 'document_id manquant' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ------------------------------------------------------------
    // 3) Récupérer les métadonnées du document
    //    (la RLS garantit déjà que c'est bien SON document, on double
    //    vérifie quand même avec .eq('user_id', user.id))
    // ------------------------------------------------------------
    const { data: document, error: docError } = await supabase
      .from('documents')
      .select('id, file_path, extension')
      .eq('id', documentId)
      .eq('user_id', user.id)
      .single()

    if (docError || !document) {
      return new Response(JSON.stringify({ error: 'Document introuvable' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ------------------------------------------------------------
    // 4) Télécharger le fichier depuis le bucket "course-documents"
    // ------------------------------------------------------------
    const { data: fileBlob, error: downloadError } = await supabase.storage
      .from('course-documents')
      .download(document.file_path as string)

    if (downloadError || !fileBlob) {
      throw new Error(`Téléchargement impossible : ${downloadError?.message}`)
    }

    const arrayBuffer = await fileBlob.arrayBuffer()
    const extension = (document.extension as string).toLowerCase()

    // ------------------------------------------------------------
    // 5) Extraire le texte selon le type de fichier
    // ------------------------------------------------------------
    let extractedText = ''

    switch (extension) {
      case 'txt': {
        extractedText = new TextDecoder('utf-8').decode(arrayBuffer)
        break
      }

      case 'pdf': {
        const pdf = await getDocumentProxy(new Uint8Array(arrayBuffer))
        const { text } = await extractPdfText(pdf, { mergePages: true })
        extractedText = text
        break
      }

      case 'docx': {
        const result = await mammoth.extractRawText({ arrayBuffer })
        extractedText = result.value
        break
      }

      case 'pptx': {
        extractedText = await extractPptxText(arrayBuffer)
        break
      }

      case 'doc':
      case 'ppt': {
        // Anciens formats binaires Office (pré-2007) : pas de parseur fiable
        // et léger disponible côté Deno. On échoue proprement plutôt que
        // de générer du texte corrompu.
        throw new Error(
          `Le format .${extension} (ancien format Office) n'est pas pris en charge. ` +
            `Merci de convertir le fichier en .${extension === 'doc' ? 'docx' : 'pptx'} ou .pdf.`,
        )
      }

      default: {
        throw new Error(`Extension non supportée : .${extension}`)
      }
    }

    extractedText = extractedText.trim().slice(0, MAX_STORED_CHARS)

    if (!extractedText) {
      throw new Error('Aucun texte extrait (le document est peut-être une image/scan sans texte).')
    }

    // ------------------------------------------------------------
    // 6) Sauvegarder le résultat -> le cours devient sélectionnable
    //    dans GenerateQuizScreen (extraction_status = 'completed')
    // ------------------------------------------------------------
    const { error: updateError } = await supabase
      .from('documents')
      .update({
        extracted_text: extractedText,
        extraction_status: 'completed',
      })
      .eq('id', documentId)

    if (updateError) throw updateError

    return new Response(
      JSON.stringify({ document_id: documentId, status: 'completed', chars: extractedText.length }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error(error)

    // On marque le document en "failed" pour qu'il reste visible mais
    // grisé (non sélectionnable) dans GenerateQuizScreen, plutôt que de
    // le laisser indéfiniment en "pending".
    if (documentId) {
      try {
        const authHeader = req.headers.get('Authorization')!
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_ANON_KEY')!,
          { global: { headers: { Authorization: authHeader } } },
        )
        await supabase
          .from('documents')
          .update({ extraction_status: 'failed' })
          .eq('id', documentId)
      } catch (_) {
        // best effort seulement
      }
    }

    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

// ============================================================
// Helper : extraction de texte depuis un .pptx
// Un .pptx est un zip contenant un fichier XML par slide
// (ppt/slides/slide1.xml, slide2.xml, ...) où le texte visible
// est encapsulé dans des balises <a:t>...</a:t>.
// ============================================================
async function extractPptxText(arrayBuffer: ArrayBuffer): Promise<string> {
  const zip = await JSZip.loadAsync(arrayBuffer)

  const slideFiles = Object.keys(zip.files)
    .filter((name) => /^ppt\/slides\/slide\d+\.xml$/.test(name))
    // trier slide1, slide2, ... slide10 dans le bon ordre numérique
    .sort((a, b) => {
      const numA = parseInt(a.match(/slide(\d+)\.xml/)![1], 10)
      const numB = parseInt(b.match(/slide(\d+)\.xml/)![1], 10)
      return numA - numB
    })

  const slidesText: string[] = []

  for (const fileName of slideFiles) {
    const xml = await zip.files[fileName].async('text')
    const matches = [...xml.matchAll(/<a:t>(.*?)<\/a:t>/g)]
    const text = matches
      .map((m) =>
        m[1]
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&quot;/g, '"')
          .replace(/&apos;/g, "'"),
      )
      .join(' ')
    if (text.trim()) slidesText.push(text.trim())
  }

  return slidesText.join('\n\n')
}