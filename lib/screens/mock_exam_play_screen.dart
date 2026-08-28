import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle d'une question d'examen blanc (correspond à la table mock_exam_questions)
class MockExamQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  MockExamQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory MockExamQuestion.fromMap(Map<String, dynamic> map) {
    return MockExamQuestion(
      id: map['id'] as String,
      questionText: map['question_text'] as String,
      options: List<String>.from(map['options'] as List),
      correctIndex: map['correct_index'] as int,
      explanation: (map['explanation'] ?? '') as String,
    );
  }
}

class MockExamPlayScreen extends StatefulWidget {
  final String examId;
  final String subjectName;
  final int dureeMinutes;

  const MockExamPlayScreen({
    super.key,
    required this.examId,
    required this.subjectName,
    required this.dureeMinutes,
  });

  @override
  State<MockExamPlayScreen> createState() => _MockExamPlayScreenState();
}

class _MockExamPlayScreenState extends State<MockExamPlayScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);
  static const Color correctGreen = Color(0xFF34A853);
  static const Color wrongRed = Color(0xFFEA4335);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;

  final List<MockExamQuestion> _questions = [];

  // Réponse choisie par question (index de la question -> index de l'option), -1 = pas répondu
  final Map<int, int> _reponses = {};

  int _indexActuel = 0;

  // En mode examen, on ne montre pas la correction immédiatement :
  // on répond à toutes les questions, puis on soumet tout à la fin.
  bool _examenTermine = false;
  bool _sauvegardeEnCours = false;

  Timer? _timer;
  late int _secondesRestantes;

  @override
  void initState() {
    super.initState();
    _secondesRestantes = widget.dureeMinutes * 60;
    _chargerExamen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _chargerExamen() async {
    try {
      final data = await supabase
          .from('mock_exam_questions')
          .select()
          .eq('exam_id', widget.examId)
          .order('order_index');

      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll((data as List).map((q) => MockExamQuestion.fromMap(q)));
        _chargement = false;
      });

      _demarrerChrono();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger l\'examen : $e';
        _chargement = false;
      });
    }
  }

  void _demarrerChrono() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondesRestantes <= 1) {
        timer.cancel();
        setState(() => _secondesRestantes = 0);
        // Temps écoulé : on soumet automatiquement l'examen tel quel.
        _terminerExamen();
        return;
      }
      setState(() => _secondesRestantes--);
    });
  }

  String get _tempsFormate {
    final m = _secondesRestantes ~/ 60;
    final s = _secondesRestantes % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _choisirOption(int index) {
    setState(() {
      _reponses[_indexActuel] = index;
    });
  }

  void _questionSuivante() {
    if (_indexActuel < _questions.length - 1) {
      setState(() => _indexActuel++);
    }
  }

  void _questionPrecedente() {
    if (_indexActuel > 0) {
      setState(() => _indexActuel--);
    }
  }

  void _allerA(int index) {
    setState(() => _indexActuel = index);
  }

  int get _score {
    int total = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_reponses[i] == _questions[i].correctIndex) total++;
    }
    return total;
  }

  int get _nbRepondues => _reponses.length;

  Future<void> _confirmerSoumission() async {
    final nonRepondues = _questions.length - _nbRepondues;
    if (nonRepondues > 0) {
      final confirmer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Submit exam?'),
          content: Text(
            'You still have $nonRepondues unanswered question${nonRepondues > 1 ? 's' : ''}. '
            'Do you want to submit anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep reviewing'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmer != true) return;
    }
    _terminerExamen();
  }

  Future<void> _terminerExamen() async {
    _timer?.cancel();

    setState(() {
      _examenTermine = true;
      _sauvegardeEnCours = true;
    });

    final tempsEcouleSecondes = (widget.dureeMinutes * 60) - _secondesRestantes;

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('mock_exam_attempts').insert({
          'exam_id': widget.examId,
          'user_id': user.id,
          'score': _score,
          'total_questions': _questions.length,
          'duration_taken_seconds': tempsEcouleSecondes,
          'finished_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // On n'empêche pas l'utilisateur de voir son résultat même si
        // l'enregistrement échoue (ex: pas de réseau).
      }
    }

    if (mounted) setState(() => _sauvegardeEnCours = false);
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _buildHeader() {
    final bool tempsCourt = _secondesRestantes <= 60;
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.subjectName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryNavy),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: tempsCourt ? wrongRed.withValues(alpha: 0.12) : const Color.fromARGB(255, 230, 237, 251),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: tempsCourt ? wrongRed : primaryNavy),
              const SizedBox(width: 6),
              Text(
                _tempsFormate,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tempsCourt ? wrongRed : primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_indexActuel + 1} of ${_questions.length}  •  $_nbRepondues answered',
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_indexActuel + 1) / _questions.length,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(MockExamQuestion question, int index) {
    final bool selectionnee = _reponses[_indexActuel] == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _choisirOption(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selectionnee ? accentBlue.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectionnee ? accentBlue : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selectionnee ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selectionnee ? accentBlue : Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.options[index],
                  style: const TextStyle(fontSize: 15, color: primaryNavy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _questions[_indexActuel];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primaryNavy),
          ),
          const SizedBox(height: 20),
          ...List.generate(question.options.length, (i) => _buildOption(question, i)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final bool derniereQuestion = _indexActuel == _questions.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_indexActuel > 0)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _questionPrecedente,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Previous', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          if (_indexActuel > 0) const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: derniereQuestion ? _confirmerSoumission : _questionSuivante,
                style: ElevatedButton.styleFrom(
                  backgroundColor: derniereQuestion ? correctGreen : primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  derniereQuestion ? 'Submit Exam' : 'Next',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionDots() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_questions.length, (i) {
          final bool active = i == _indexActuel;
          final bool answered = _reponses.containsKey(i);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _allerA(i),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? primaryNavy
                    : answered
                        ? accentBlue.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                border: active ? Border.all(color: primaryNavy, width: 2) : null,
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? Colors.white
                      : answered
                          ? accentBlue
                          : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildResultatsHeader() {
    final total = _questions.length;
    final pourcentage = total == 0 ? 0 : ((_score / total) * 100).round();

    return Column(
      children: [
        Icon(
          pourcentage >= 50 ? Icons.emoji_events : Icons.refresh,
          size: 64,
          color: pourcentage >= 50 ? const Color(0xFFF9D20E) : Colors.grey,
        ),
        const SizedBox(height: 16),
        const Text(
          'Exam finished!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
        ),
        const SizedBox(height: 8),
        Text(
          '$_score / $total correct ($pourcentage%)',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildReviewList() {
    return Column(
      children: List.generate(_questions.length, (i) {
        final q = _questions[i];
        final userIndex = _reponses[i];
        final bool repondue = userIndex != null;
        final bool correcte = repondue && userIndex == q.correctIndex;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    !repondue
                        ? Icons.remove_circle_outline
                        : correcte
                            ? Icons.check_circle
                            : Icons.cancel,
                    color: !repondue ? Colors.grey : (correcte ? correctGreen : wrongRed),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Q${i + 1}. ${q.questionText}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: primaryNavy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Correct answer: ${q.options[q.correctIndex]}',
                style: const TextStyle(color: correctGreen, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              if (repondue && !correcte)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Your answer: ${q.options[userIndex]}',
                    style: const TextStyle(color: wrongRed, fontSize: 13.5),
                  ),
                ),
              if (!repondue)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Not answered',
                    style: TextStyle(color: Colors.grey, fontSize: 13.5, fontStyle: FontStyle.italic),
                  ),
                ),
              if (q.explanation.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 230, 237, 251),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    q.explanation,
                    style: const TextStyle(color: primaryNavy, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildResultats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildResultatsHeader(),
          const SizedBox(height: 24),
          if (_sauvegardeEnCours)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to home', style: TextStyle(color: Colors.white)),
              ),
            ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
            ),
          ),
          _buildReviewList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // On empêche de quitter l'examen par erreur avec le bouton retour
      // tant qu'il n'est pas terminé.
      canPop: _examenTermine,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _examenTermine) return;
        final quitter = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Leave the exam?'),
            content: const Text('Your progress will be lost if you leave now.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: wrongRed),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (quitter == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text('Mock Exam', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : _erreur != null
                  ? Center(child: Text(_erreur!, style: const TextStyle(color: Colors.red)))
                  : _questions.isEmpty
                      ? const Center(child: Text('This exam contains no questions.'))
                      : _examenTermine
                          ? _buildResultats()
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(),
                                  _buildProgress(),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          _buildQuestionCard(),
                                          _buildQuestionDots(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildNavigationButtons(),
                                ],
                              ),
                            ),
        ),
      ),
    );
  }
}