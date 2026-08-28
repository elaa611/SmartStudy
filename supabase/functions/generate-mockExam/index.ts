import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// En dessous de ce score moyen (%), une matière est considérée comme "faible".
const WEAKNESS_THRESHOLD = 70;
// On ne regarde que les N tentatives de quiz les plus récentes de l'utilisateur.
const RECENT_ATTEMPTS_LIMIT = 30;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Dernières tentatives de quiz, avec la matière associée à chaque quiz.
    const { data: attempts, error: attemptsError } = await supabase
      .from("quiz_attempts")
      .select(
        "id, quiz_id, score, finished_at, quizzes!inner(id, title, subject_id, subjects!inner(id, name))",
      )
      .eq("user_id", user.id)
      .order("finished_at", { ascending: false })
      .limit(RECENT_ATTEMPTS_LIMIT);

    if (attemptsError) throw attemptsError;

    if (!attempts || attempts.length === 0) {
      // Pas encore assez d'historique pour dégager une insight.
      return jsonResponse({ has_insight: false });
    }

    // 2. Nombre de questions par quiz, pour transformer un score brut en %.
    const quizIds = [...new Set(attempts.map((a: any) => a.quiz_id))];
    const { data: questionRows, error: questionsError } = await supabase
      .from("quiz_questions")
      .select("quiz_id")
      .in("quiz_id", quizIds);

    if (questionsError) throw questionsError;

    const questionCountByQuiz: Record<string, number> = {};
    for (const q of questionRows ?? []) {
      questionCountByQuiz[q.quiz_id] = (questionCountByQuiz[q.quiz_id] ?? 0) + 1;
    }

    // 3. Moyenne des scores (%) par matière, + on garde le titre du quiz
    //    le plus récent comme proxy du "sujet" travaillé (weak_topic).
    type SubjectAgg = {
      name: string;
      totalPct: number;
      count: number;
      mostRecentQuizTitle: string;
    };
    const bySubject = new Map<number, SubjectAgg>();

    for (const attempt of attempts as any[]) {
      const totalQuestions = questionCountByQuiz[attempt.quiz_id] ?? 0;
      if (totalQuestions === 0) continue;

      const pct = (attempt.score / totalQuestions) * 100;
      const subjectId = attempt.quizzes.subject_id as number;
      const subjectName = attempt.quizzes.subjects?.name ?? "this subject";

      const existing = bySubject.get(subjectId);
      if (existing) {
        existing.totalPct += pct;
        existing.count += 1;
      } else {
        bySubject.set(subjectId, {
          name: subjectName,
          totalPct: pct,
          count: 1,
          // attempts est trié du plus récent au plus ancien, donc le
          // premier quiz rencontré pour cette matière est le plus récent.
          mostRecentQuizTitle: attempt.quizzes.title,
        });
      }
    }

    // 4. On choisit la matière avec la moyenne la plus basse.
    let weakestSubjectId: number | null = null;
    let weakest: SubjectAgg | null = null;
    let weakestAvg = Infinity;

    for (const [subjectId, agg] of bySubject.entries()) {
      const avg = agg.totalPct / agg.count;
      if (avg < weakestAvg) {
        weakestAvg = avg;
        weakest = agg;
        weakestSubjectId = subjectId;
      }
    }

    if (!weakest || weakestSubjectId === null || weakestAvg >= WEAKNESS_THRESHOLD) {
      // L'utilisateur s'en sort bien partout : pas d'insight à pousser aujourd'hui.
      return jsonResponse({ has_insight: false });
    }

    // 5. Cours exploitables de cette matière, pour pré-remplir les écrans
    
    const { data: docs, error: docsError } = await supabase
      .from("documents")
      .select("id")
      .eq("subject_id", weakestSubjectId)
      .eq("user_id", user.id)
      .eq("extraction_status", "completed");

    if (docsError) throw docsError;

    return jsonResponse({
      has_insight: true,
      subject_id: weakestSubjectId,
      subject_name: weakest.name,
      weak_topic: weakest.mostRecentQuizTitle,
      readiness_score: Math.round(weakestAvg),
      document_ids: (docs ?? []).map((d: any) => d.id),
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function jsonResponse(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}