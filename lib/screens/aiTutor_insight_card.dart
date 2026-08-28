import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'generate_flashcards_screen.dart';
import 'generate_mock_exam_screen.dart';

class AiTutorInsightCard extends StatefulWidget {
  const AiTutorInsightCard({super.key});

  @override
  State<AiTutorInsightCard> createState() => _AiTutorInsightCardState();
}

class _WeakSubjectInsight {
  final int subjectId;
  final String subjectName;
  final double averagePercent;

  _WeakSubjectInsight({
    required this.subjectId,
    required this.subjectName,
    required this.averagePercent,
  });
}

class _AiTutorInsightCardState extends State<AiTutorInsightCard> {
  static const Color primaryNavy = Color(0xFF0B1F5C);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  _WeakSubjectInsight? _insight;

  @override
  void initState() {
    super.initState();
    _detecterPointFaible();
  }

  //1- On regarde les tentatives de quiz récentes de l'utilisateur,
  //2- on calcule le pourcentage de réussite par matière, et on retient
  //3- la matière avec la moyenne la plus basse (le "point faible").
  Future<void> _detecterPointFaible() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }
    

    try {
      final data = await supabase
          .from('quiz_attempts')
          .select(
            'score, quiz_id, quizzes!inner(subject_id, subjects!inner(name), quiz_questions(count))',
          )
          .eq('user_id', user.id)
          .order('finished_at', ascending: false)
          .limit(30);

      final Map<int, List<double>> percentsBySubject = {};
      final Map<int, String> namesBySubject = {};

      for (final row in (data as List)) {
        final quiz = row['quizzes'];
        if (quiz == null) continue;

        final subjectId = quiz['subject_id'] as int?;
        final subjectName = quiz['subjects']?['name'] as String?;
        final questionsCountList = quiz['quiz_questions'] as List?;
        final total = (questionsCountList != null && questionsCountList.isNotEmpty)
            ? (questionsCountList.first['count'] as num?)?.toInt() ?? 0
            : 0;
        final score = (row['score'] as num?)?.toInt() ?? 0;

        if (subjectId == null || subjectName == null || total <= 0) continue;

        final pct = (score / total) * 100;
        percentsBySubject.putIfAbsent(subjectId, () => []).add(pct);
        namesBySubject[subjectId] = subjectName;
      }

      if (percentsBySubject.isEmpty) {
        if (mounted) setState(() => _chargement = false);
        return;
      }

      int? faibleId;
      double faibleMoyenne = 101;

      percentsBySubject.forEach((subjectId, percents) {
        final moyenne = percents.reduce((a, b) => a + b) / percents.length;
        if (moyenne < faibleMoyenne) {
          faibleMoyenne = moyenne;
          faibleId = subjectId;
        }
      });

      if (!mounted || faibleId == null) {
        if (mounted) setState(() => _chargement = false);
        return;
      }

      setState(() {
        _insight = _WeakSubjectInsight(
          subjectId: faibleId!,
          subjectName: namesBySubject[faibleId]!,
          averagePercent: faibleMoyenne,
        );
        _chargement = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _reviserPointFaible() {
    final insight = _insight;
    if (insight == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateFlashcardsScreen(
          initialSubjectId: insight.subjectId,
        ),
      ),
    );
  }

  void _demarrerExamenBlanc() {
    final insight = _insight;
    if (insight == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateMockExamScreen(
          initialSubjectId: insight.subjectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const SizedBox.shrink();
    final insight = _insight;
    if (insight == null) return const SizedBox.shrink();

    final pct = insight.averagePercent.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: primaryNavy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Tutor Insight',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14.5, height: 1.4, color: Colors.grey.shade800),
              children: [
                const TextSpan(text: 'You struggle with '),
                TextSpan(
                  text: insight.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                ),
                TextSpan(
                  text: '. Based on your recent quizzes (avg. $pct%), reviewing it today will '
                      'yield the highest impact on your readiness score.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _reviserPointFaible,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 20),
              label: const Text(
                'Review Weak Concepts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _demarrerExamenBlanc,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEDEEF2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.assignment_outlined, color: primaryNavy, size: 20),
              label: const Text(
                'Start Mock Exam',
                style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}