import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qa_play_screen.dart';

class Matiere {
  final int id;
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

class Cours {
  final String id; 
  final String nom; 
  final String extension;
  final String extractionStatus;

  Cours({
    required this.id,
    required this.nom,
    required this.extension,
    required this.extractionStatus,
  });

  bool get estExploitable => extractionStatus == 'completed';
}

class GenerateQAScreen extends StatefulWidget {
  const GenerateQAScreen({super.key});

  @override
  State<GenerateQAScreen> createState() => _GenerateQAScreenState();
}

class _GenerateQAScreenState extends State<GenerateQAScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  final supabase = Supabase.instance.client;

  final List<Matiere> _matieres = [];
  Matiere? _matiereSelectionnee;
  bool _chargementMatieres = true;

  final List<Cours> _cours = [];
  final Set<String> _coursSelectionnes = {}; // ids des documents cochés
  bool _chargementCours = false;

  int _nbQuestions = 10;

  bool _generationEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerMatieres();
  }

  // ÉTAPE 1 : charger les matières de l'utilisateur
  Future<void> _chargerMatieres() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('subjects')
        .select()
        .eq('user_id', user.id)
        .order('created_at');

    if (!mounted) return;
    setState(() {
      _matieres
        ..clear()
        ..addAll(
          data.map(
            (s) => Matiere(
              id: s['id'] as int,
              nom: s['name'],
              icon: IconData(s['icon'], fontFamily: 'MaterialIcons'),
              color: Color(s['color']),
            ),
          ),
        );
      _chargementMatieres = false;
    });
  }

  // ÉTAPE 2 : quand l'utilisateur choisit une matière -> charger SES cours
  Future<void> _selectionnerMatiere(Matiere matiere) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _matiereSelectionnee = matiere;
      _chargementCours = true;
      _cours.clear();
      _coursSelectionnes.clear();
    });

    final data = await supabase
        .from('documents')
        .select('id, file_name, extension, extraction_status')
        .eq('subject_id', matiere.id)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _cours
        ..clear()
        ..addAll(
          data.map(
            (d) => Cours(
              id: d['id'] as String,
              nom: d['file_name'] as String,
              extension: d['extension'] as String,
              extractionStatus: (d['extraction_status'] ?? 'pending') as String,
            ),
          ),
        );
      _chargementCours = false;
    });
  }

  void _toggleCours(String id) {
    setState(() {
      if (_coursSelectionnes.contains(id)) {
        _coursSelectionnes.remove(id);
      } else {
        _coursSelectionnes.add(id);
      }
    });
  }

  // ÉTAPE 3 : appeler l'Edge Function Supabase pour générer le Q/A
  Future<void> _genererQA() async {
    if (_matiereSelectionnee == null) {
      _showError('Choisis une matière');
      return;
    }
    if (_coursSelectionnes.isEmpty) {
      _showError('Sélectionne au moins un cours');
      return;
    }

    setState(() => _generationEnCours = true);

    try {
      final response = await supabase.functions.invoke(
        'generate-qa',
        body: {
          'subject_id': _matiereSelectionnee!.id,
          'document_ids': _coursSelectionnes.toList(),
          'nb_questions': _nbQuestions,
          'subject_name': _matiereSelectionnee!.nom,
        },
      );

      if (!mounted) return;

      if (response.status != 200) {
        _showError('Erreur serveur (${response.status})');
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final qaSetId = data['qa_set_id'] as String;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QAPlayScreen(
            setId: qaSetId,
            subjectName: _matiereSelectionnee!.nom,
          ),
        ),
      );
    } catch (e) {
      _showError('Impossible de générer les questions/réponses : $e');
    } finally {
      if (mounted) setState(() => _generationEnCours = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // UI

  Widget _buildMatieresGrid() {
    if (_chargementMatieres) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: _matieres.map((m) {
        final bool selectionnee = _matiereSelectionnee?.id == m.id;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectionnerMatiere(m),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selectionnee ? primaryNavy : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectionnee ? primaryNavy : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(m.icon, color: selectionnee ? Colors.white : m.color),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    m.nom,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selectionnee ? Colors.white : primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoursSection() {
    if (_matiereSelectionnee == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📚 Choose courses',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy),
          ),
          const SizedBox(height: 4),
          Text(
            'The questions will be generated only from the selected courses.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_chargementCours)
            const Center(child: CircularProgressIndicator())
          else if (_cours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No courses have been uploaded for this subject.\nPlease upload a document first.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ..._cours.map((c) {
              final bool exploitable = c.estExploitable;
              final bool coche = _coursSelectionnes.contains(c.id);
              return Opacity(
                opacity: exploitable ? 1 : 0.4,
                child: CheckboxListTile(
                  enabled: exploitable,
                  value: coche,
                  onChanged: exploitable ? (_) => _toggleCours(c.id) : null,
                  activeColor: accentBlue,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(c.nom, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    exploitable
                        ? c.extension.toUpperCase()
                        : 'Text extraction in progress...',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuestionsCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.quiz_outlined, color: primaryNavy),
          const SizedBox(width: 8),
          const Text('Questions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() {
              if (_nbQuestions > 5) _nbQuestions -= 5;
            }),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$_nbQuestions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () => setState(() {
              if (_nbQuestions < 30) _nbQuestions += 5;
            }),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
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
        title: const Text(
          'SmartStudy',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generate New Q&A',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: primaryNavy)),
              const SizedBox(height: 6),
              Text(
                'Get clear, personalized questions and answers to deepen your understanding.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              const Text('Select Subject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildMatieresGrid(),
              _buildCoursSection(),
              _buildQuestionsCounter(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _generationEnCours ? null : _genererQA,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _generationEnCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  label: Text(
                    _generationEnCours ? 'Generation in progress...' : 'Generate Q&A',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}