import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';

class QAItem {
  final String id;
  final String question;
  final String answer;

  QAItem({required this.id, required this.question, required this.answer});

  factory QAItem.fromMap(Map<String, dynamic> map) {
    return QAItem(
      id: map['id'] as String,
      question: map['question'] as String,
      answer: map['answer'] as String,
    );
  }
}

class QAPlayScreen extends StatefulWidget {
  final String setId;
  final String subjectName;

  const QAPlayScreen({
    super.key,
    required this.setId,
    required this.subjectName,
  });

  @override
  State<QAPlayScreen> createState() => _QAPlayScreenState();
}

class _QAPlayScreenState extends State<QAPlayScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;

  final List<QAItem> _questions = [];

  int _indexActuel = 0;
  bool _reponseVisible = false;

  bool _sessionTerminee = false;
  bool _sauvegardeEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerQA();
  }

  Future<void> _chargerQA() async {
    try {
      final data = await supabase
          .from('qa_items')
          .select()
          .eq('set_id', widget.setId)
          .order('order_index');

      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll((data as List).map((q) => QAItem.fromMap(q)));
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger les questions : $e';
        _chargement = false;
      });
    }
  }

  void _revelerReponse() {
    setState(() => _reponseVisible = true);
  }

  void _questionSuivante() {
    final derniereQuestion = _indexActuel == _questions.length - 1;
    if (derniereQuestion) {
      _terminerSession();
      return;
    }
    setState(() {
      _indexActuel++;
      _reponseVisible = false;
    });
  }

  Future<void> _terminerSession() async {
    setState(() {
      _sessionTerminee = true;
      _sauvegardeEnCours = true;
    });

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('qa_attempts').insert({
          'set_id': widget.setId,
          'user_id': user.id,
          'reviewed_count': _questions.length,
          'finished_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // On n'empêche pas l'utilisateur de voir la fin de session même si l'enregistrement échoue
      }
    }

    if (mounted) setState(() => _sauvegardeEnCours = false);
  }

  void _recommencer() {
    setState(() {
      _indexActuel = 0;
      _reponseVisible = false;
      _sessionTerminee = false;
    });
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 222, 229, 251),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: primaryNavy, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.subjectName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 230, 230, 235),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Q ${_indexActuel + 1} of ${_questions.length}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: primaryNavy),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final item = _questions[_indexActuel];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: accentBlue),
              const SizedBox(width: 8),
              const Text(
                'Question',
                style: TextStyle(fontWeight: FontWeight.bold, color: accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.question,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryNavy),
          ),
          const SizedBox(height: 20),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _reponseVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _revelerReponse,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: accentBlue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.visibility_outlined, color: accentBlue),
                label: const Text('Show Answer', style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
              ),
            ),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 237, 251),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb_outline, color: primaryNavy, size: 20),
                      SizedBox(width: 8),
                      Text('Answer', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.answer,
                    style: const TextStyle(color: primaryNavy, fontSize: 14.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultats() {
    final total = _questions.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Color(0xFFF9D20E)),
            const SizedBox(height: 16),
            const Text(
              'Q&A session finished!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'You reviewed $total question${total > 1 ? 's' : ''}.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            if (_sauvegardeEnCours)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _recommencer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Review again', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: Colors.grey.shade300),
        NavigationBar(
          backgroundColor: Colors.white,
          height: 80,
          selectedIndex: 1,
          indicatorColor: const Color.fromARGB(255, 222, 229, 251),
          onDestinationSelected: (index) {
            if (index == 0) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
            }
            if (index == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
            }
            if (index == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PlanScreen()));
            }
            if (index == 4) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Study'),
            NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'AI Chat'),
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Plan'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _erreur != null
                ? Center(child: Text(_erreur!, style: const TextStyle(color: Colors.red)))
                : _questions.isEmpty
                    ? const Center(child: Text('This set contains no questions.'))
                    : _sessionTerminee
                        ? _buildResultats()
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 24),
                                Expanded(child: SingleChildScrollView(child: _buildCard())),
                                const SizedBox(height: 16),
                                if (_reponseVisible)
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
                                        _indexActuel == _questions.length - 1 ? 'See results' : 'Next question',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
      ),
      bottomNavigationBar: _sessionTerminee || _chargement ? null : _buildBottomNav(),
    );
  }
}