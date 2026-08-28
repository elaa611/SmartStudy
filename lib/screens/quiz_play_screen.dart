import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle d'une question de quiz (correspond à la table quiz_questions)
class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] as String,
      questionText: map['question_text'] as String,
      // options est une colonne jsonb -> Supabase la renvoie déjà comme List<dynamic>
      options: List<String>.from(map['options'] as List),
      correctIndex: map['correct_index'] as int,
      explanation: (map['explanation'] ?? '') as String,
    );
  }
}

class QuizPlayScreen extends StatefulWidget {
  final String quizId;

  const QuizPlayScreen({super.key, required this.quizId});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);
  static const Color correctGreen = Color(0xFF34A853);
  static const Color wrongRed = Color(0xFFEA4335);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;
  String _titreQuiz = '';

  final List<QuizQuestion> _questions = [];

  int _indexActuel = 0;
  int? _optionChoisie; // index de l'option choisie pour la question actuelle
  bool _reponseValidee = false; // true dès qu'on a choisi une réponse (affiche le feedback)
  int _score = 0;

  bool _quizTermine = false;
  bool _sauvegardeEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerQuiz();
  }

  Future<void> _chargerQuiz() async {
    try {
      final quiz = await supabase
          .from('quizzes')
          .select('title')
          .eq('id', widget.quizId)
          .single();

      // Toutes les questions du quiz, triées par order_index
      // (ordre choisi lors de la génération, cf. Edge Function generate-quiz)
      final data = await supabase
          .from('quiz_questions')
          .select()
          .eq('quiz_id', widget.quizId)
          .order('order_index');

      if (!mounted) return;
      setState(() {
        _titreQuiz = quiz['title'] as String? ?? 'Quiz';
        _questions
          ..clear()
          ..addAll((data as List).map((q) => QuizQuestion.fromMap(q)));
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger le quiz : $e';
        _chargement = false;
      });
    }
  }

  // ============================================================
  // ÉTAPE 2 : logique de réponse
  // ============================================================
  void _choisirOption(int index) {
    if (_reponseValidee) return; // on ne peut pas changer après validation

    final question = _questions[_indexActuel];
    final estCorrecte = index == question.correctIndex;

    setState(() {
      _optionChoisie = index;
      _reponseValidee = true;
      if (estCorrecte) _score++;
    });
  }

  void _questionSuivante() {
    final dernierQuestion = _indexActuel == _questions.length - 1;

    if (dernierQuestion) {
      _terminerQuiz();
      return;
    }

    setState(() {
      _indexActuel++;
      _optionChoisie = null;
      _reponseValidee = false;
    });
  }

  // ÉTAPE 3 : à la fin -> enregistrer le score dans quiz_attempts
  Future<void> _terminerQuiz() async {
    setState(() {
      _quizTermine = true;
      _sauvegardeEnCours = true;
    });

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('quiz_attempts').insert({
          'quiz_id': widget.quizId,
          'user_id': user.id,
          'score': _score,
          'finished_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // On n'empêche pas l'utilisateur de voir son score
        // même si l'enregistrement échoue (ex: pas de réseau).
      }
    }

    if (mounted) setState(() => _sauvegardeEnCours = false);
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _buildOption(QuizQuestion question, int index) {
    final bool estChoisie = _optionChoisie == index;
    final bool estCorrecte = index == question.correctIndex;

    Color bordure = Colors.grey.shade300;
    Color fond = Colors.white;
    Widget? icone;

    if (_reponseValidee) {
      if (estCorrecte) {
        // La bonne réponse est toujours surlignée en vert une fois validé
        bordure = correctGreen;
        fond = correctGreen.withValues(alpha: 0.08);
        icone = const Icon(Icons.check_circle, color: correctGreen);
      } else if (estChoisie && !estCorrecte) {
        // L'option choisie par l'utilisateur, si fausse, en rouge
        bordure = wrongRed;
        fond = wrongRed.withValues(alpha: 0.08);
        icone = const Icon(Icons.cancel, color: wrongRed);
      }
    } else if (estChoisie) {
      bordure = accentBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _choisirOption(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: fond,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bordure, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  question.options[index],
                  style: const TextStyle(fontSize: 15, color: primaryNavy),
                ),
              ),
              if (icone != null) icone,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _questions[_indexActuel];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de progression
          Row(
            children: [
              Text(
                'Question ${_indexActuel + 1}/${_questions.length}',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'Score: $_score',
                style: const TextStyle(color: accentBlue, fontWeight: FontWeight.bold),
              ),
            ],
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
          const SizedBox(height: 24),

          // Texte de la question
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              question.questionText,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primaryNavy),
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...List.generate(question.options.length, (i) => _buildOption(question, i)),

          // Explication (affichée seulement après avoir répondu)
          if (_reponseValidee && question.explanation.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 237, 251),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: primaryNavy, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: const TextStyle(color: primaryNavy, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          if (_reponseValidee)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _questionSuivante,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _indexActuel == _questions.length - 1 ? 'Voir le résultat' : 'Question suivante',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultats() {
    final total = _questions.length;
    final pourcentage = total == 0 ? 0 : ((_score / total) * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pourcentage >= 50 ? Icons.emoji_events : Icons.refresh,
              size: 64,
              color: pourcentage >= 50 ? const Color(0xFFF9D20E) : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Quiz terminé !',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / $total bonnes réponses ($pourcentage%)',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
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
                  child: const Text('Retour à l\'accueil', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        title: Text(_titreQuiz),
        centerTitle: true,
        automaticallyImplyLeading: !_quizTermine, // on bloque le retour arrière pendant le quiz
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _erreur != null
                ? Center(child: Text(_erreur!, style: const TextStyle(color: Colors.red)))
                : _questions.isEmpty
                    ? const Center(child: Text('Ce quiz ne contient aucune question.'))
                    : _quizTermine
                        ? _buildResultats()
                        : _buildQuestionCard(),
      ),
    );
  }
}