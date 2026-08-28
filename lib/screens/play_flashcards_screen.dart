import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';

class Flashcard {
  final String id;
  final String term;
  final String definition;

  Flashcard({required this.id, required this.term, required this.definition});

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as String,
      term: map['term'] as String,
      definition: map['definition'] as String,
    );
  }
}

class FlashcardPlayScreen extends StatefulWidget {
  final String setId;
  final String subjectName;

  const FlashcardPlayScreen({
    super.key,
    required this.setId,
    required this.subjectName,
  });

  @override
  State<FlashcardPlayScreen> createState() => _FlashcardPlayScreenState();
}

class _FlashcardPlayScreenState extends State<FlashcardPlayScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);
  static const Color wrongRed = Color(0xFFEA4335);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;

  final List<Flashcard> _cartes = [];

  int _indexActuel = 0;
  bool _retournee =
      false; // false = on voit le terme, true = on voit la définition

  int _cartesConnues = 0;
  int _cartesARevoir = 0;

  bool _sessionTerminee = false;
  bool _sauvegardeEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerFlashcards();
  }

  Future<void> _chargerFlashcards() async {
    try {
      final data = await supabase
          .from('flashcards')
          .select()
          .eq('set_id', widget.setId)
          .order('order_index');

      if (!mounted) return;
      setState(() {
        _cartes
          ..clear()
          ..addAll((data as List).map((c) => Flashcard.fromMap(c)));
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger les flashcards : $e';
        _chargement = false;
      });
    }
  }

  void _retournerCarte() {
    setState(() => _retournee = !_retournee);
  }

  void _repondre(bool connue) {
    if (!_retournee) return;

    setState(() {
      if (connue) {
        _cartesConnues++;
      } else {
        _cartesARevoir++;
      }
    });

    final derniereCarte = _indexActuel == _cartes.length - 1;
    if (derniereCarte) {
      _terminerSession();
      return;
    }

    setState(() {
      _indexActuel++;
      _retournee = false;
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
        await supabase.from('flashcard_attempts').insert({
          'set_id': widget.setId,
          'user_id': user.id,
          'known_count': _cartesConnues,
          'review_count': _cartesARevoir,
          'finished_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
      }
    }

    if (mounted) setState(() => _sauvegardeEnCours = false);
  }

  void _recommencer() {
    setState(() {
      _indexActuel = 0;
      _retournee = false;
      _cartesConnues = 0;
      _cartesARevoir = 0;
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryNavy,
            ),
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
            'Card ${_indexActuel + 1} of ${_cartes.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryNavy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final carte = _cartes[_indexActuel];

    return GestureDetector(
      onTap: _retournerCarte,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Container(
          key: ValueKey('$_indexActuel-$_retournee'),
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
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.volume_up_outlined,
                  color: Colors.grey.shade400,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _retournee ? carte.definition : carte.term,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _retournee ? 18 : 26,
                      fontWeight: _retournee
                          ? FontWeight.w500
                          : FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                ),
              ),
              Text(
                _retournee ? 'Tap to flip back' : 'Tap to flip',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoutonsReponse() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildBoutonRond(
            couleur: wrongRed.withValues(alpha: 0.12),
            icone: Icons.close,
            iconeCouleur: wrongRed,
            onTap: () => _repondre(false),
          ),
          const SizedBox(width: 24),
          _buildBoutonRond(
            couleur: accentBlue,
            icone: Icons.check,
            iconeCouleur: Colors.white,
            onTap: () => _repondre(true),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutonRond({
    required Color couleur,
    required IconData icone,
    required Color iconeCouleur,
    required VoidCallback onTap,
  }) {
    final bool actif = _retournee;
    return Opacity(
      opacity: actif ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: actif ? onTap : null,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          child: Icon(icone, color: iconeCouleur, size: 28),
        ),
      ),
    );
  }

  Widget _buildResultats() {
    final total = _cartes.length;
    final pourcentage = total == 0
        ? 0
        : ((_cartesConnues / total) * 100).round();

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
            const Text(
              'Session finished !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_cartesConnues / $total cards known ($pourcentage%)',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Review again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to home',
                    style: TextStyle(color: Colors.white),
                  ),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
            if (index == 2) {
              showChatModal(context);
            }
            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlanScreen()),
              );
            }
            if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Study',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              label: 'AI Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              label: 'Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
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
            ? Center(
                child: Text(
                  _erreur!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _cartes.isEmpty
            ? const Center(child: Text('This set contains no flashcards.'))
            : _sessionTerminee
            ? _buildResultats()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Expanded(child: _buildCard()), // <- ajoute Expanded ici
                    _buildBoutonsReponse(),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _sessionTerminee || _chargement
          ? null
          : _buildBottomNav(),
    );
  }
}
