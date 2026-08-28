import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'revisionCenter_screen.dart';
import 'home_screen.dart';
import 'subject_screen.dart';
import 'profile_screen.dart';
import 'plan_screen.dart';

class Matiere {
  final int id; // correspond à subjects.id dans Supabase (clé primaire)
  final String nom;
  final IconData icon;
  final Color color;

  Matiere({
    required this.id,
    required this.nom,
    required this.icon,
    required this.color,
  });
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  final List<IconData> _iconChoices = [
    Icons.book_outlined,
    Icons.calculate_outlined,
    Icons.science_outlined,
    Icons.biotech_outlined,
    Icons.menu_book_outlined,
    Icons.language_outlined,
    Icons.history_edu_outlined,
  ];

  final List<Color> _colorChoices = [
    accentBlue,
    const Color(0xFF34A853),
    const Color(0xFFEA4335),
    const Color.fromARGB(255, 249, 210, 14),
    const Color.fromARGB(255, 146, 47, 163),
    const Color.fromARGB(255, 241, 58, 168),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    //sert à nettoyer et libérer les ressources utilisées par un widget avant qu'il soit détruit
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStudyTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 237, 251),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'My Subjects',
                  style: TextStyle(
                    fontSize: 15,
                    //fontFamily: 'Pacifico',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B2A6F),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RevisionScreen(),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Revision Center',
                    style: TextStyle(
                      fontSize: 15,
                      //fontFamily: 'Pacifico',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0B2A6F),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: 'Search',
          border: InputBorder.none,
        ),
      ),
    );
  }

  final List<Matiere> _matieres = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final data = await Supabase.instance.client
        .from('subjects')
        .select()
        .eq('user_id', user.id)
        .order('created_at');

    setState(() {
      _matieres.clear();

      for (final subject in data) {
        _matieres.add(
          Matiere(
            id: subject['id'] as int,
            nom: subject['name'],
            icon: IconData(subject['icon'], fontFamily: 'MaterialIcons'),
            color: Color(subject['color']),
          ),
        );
      }
    });
  }

  Future<void> _ajouterMatiere(String nom, IconData icon, Color color) async {
    if (nom.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    await Supabase.instance.client.from('subjects').insert({
      'user_id': user.id,
      'name': nom.trim(),
      'icon': icon.codePoint,
      'color': color.toARGB32(),
    });

    await _loadSubjects();
  }

  List<Matiere> get _matieresFiltrees {
    if (_query.trim().isEmpty) return _matieres;
    return _matieres
        .where(
          (matiere) => matiere.nom.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
  }

  Widget _buildMatieresSection() {
    final matieres = _matieresFiltrees;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subjects',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryNavy,
            ),
          ),
          const SizedBox(height: 12),
          if (matieres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _matieres.isEmpty
                      ? 'No subjects found'
                      : 'No results for "${_query}"',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...List.generate(matieres.length, (index) {
              return _buildMatiereTile(matieres[index], isFirst: index == 0);
            }),
          SizedBox(height: 8),
          InkWell(
            onTap: _ouvrirDialogueAjout,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add, color: accentBlue),
                  SizedBox(width: 8),
                  Text(
                    'Add subject',
                    style: TextStyle(
                      color: accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatiereTile(Matiere matiere, {bool isFirst = false}) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            //rend la matière cliquable
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubjectScreen(
                    subjectId: matiere.id,
                    subjectName: matiere.nom,
                    subjectIcon: matiere.icon,
                    subjectColor: matiere.color,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                border: isFirst
                    ? const Border(
                        left: BorderSide(
                          color: Color.fromARGB(255, 92, 106, 133),
                          width: 4,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: matiere.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(matiere.icon, color: matiere.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      matiere.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryNavy,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _ouvrirDialogueAjout() async {
    final TextEditingController nomController = TextEditingController();
    IconData iconSelectionnee = _iconChoices.first;
    Color couleurSelectionnee = _colorChoices.first;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add New Subject',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: background,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Name of subject',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Icon'),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconChoices.map((icon) {
                        final bool selected = icon == iconSelectionnee;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              iconSelectionnee = icon;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? couleurSelectionnee.withValues(alpha: 0.15)
                                  : const Color.fromARGB(255, 233, 236, 251),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? couleurSelectionnee
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, color: primaryNavy),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Text('Color'),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorChoices.map((color) {
                        final bool selected = color == couleurSelectionnee;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              couleurSelectionnee = color;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
                  onPressed: () async {
                    await _ajouterMatiere(
                      nomController.text,
                      iconSelectionnee,
                      couleurSelectionnee,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Ouvre le menu
          },
        ),
        backgroundColor: primaryNavy,
        title: const Text(
          'SmartStudy',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudyTabs(),
              const SizedBox(height: 10),
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildMatieresSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
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
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
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
      ),
    );
  }
}