import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'generate_quiz_screen.dart';

/// Modèle d'un résumé (correspond à la table `summaries`)
class Summary {
  final String id;
  final int subjectId;
  final String title;
  final List<String> keyIdeas;
  final List<Map<String, String>> definitions;
  final List<String> formulas;
  final List<String> documentIds;

  Summary({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.keyIdeas,
    required this.definitions,
    required this.formulas,
    required this.documentIds,
  });

  factory Summary.fromMap(Map<String, dynamic> map) {
    final rawDefs = (map['definitions'] as List?) ?? [];
    final rawFormulas = (map['formulas'] as List?) ?? [];
    final rawDocs = (map['document_ids'] as List?) ?? [];

    return Summary(
      id: map['id'] as String,
      subjectId: map['subject_id'] as int,
      title: (map['title'] ?? 'Summary') as String,
      keyIdeas: List<String>.from((map['key_ideas'] as List?) ?? []),
      definitions: rawDefs
          .map<Map<String, String>>(
            (d) => {
              'term': (d['term'] ?? '').toString(),
              'definition': (d['definition'] ?? '').toString(),
            },
          )
          .toList(),
      formulas: List<String>.from(rawFormulas),
      documentIds: List<String>.from(rawDocs),
    );
  }
}

class SummaryResultScreen extends StatefulWidget {
  final String summaryId;
  final String subjectName;

  const SummaryResultScreen({
    super.key,
    required this.summaryId,
    required this.subjectName,
  });

  @override
  State<SummaryResultScreen> createState() => _SummaryResultScreenState();
}

class _SummaryResultScreenState extends State<SummaryResultScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  final supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;
  Summary? _resume;

  @override
  void initState() {
    super.initState();
    _chargerResume();
  }

  Future<void> _chargerResume() async {
    try {
      final data = await supabase
          .from('summaries')
          .select()
          .eq('id', widget.summaryId)
          .single();

      if (!mounted) return;
      setState(() {
        _resume = Summary.fromMap(data);
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger le résumé : $e';
        _chargement = false;
      });
    }
  }

  void _copierResume() {
    final resume = _resume;
    if (resume == null) return;

    final buffer = StringBuffer()
      ..writeln(resume.title)
      ..writeln();

    if (resume.keyIdeas.isNotEmpty) {
      buffer.writeln('Key Ideas:');
      for (final idea in resume.keyIdeas) {
        buffer.writeln('- $idea');
      }
      buffer.writeln();
    }

    if (resume.definitions.isNotEmpty) {
      buffer.writeln('Definitions:');
      for (final d in resume.definitions) {
        buffer.writeln('${d['term']}: ${d['definition']}');
      }
      buffer.writeln();
    }

    if (resume.formulas.isNotEmpty) {
      buffer.writeln('Important Formulas:');
      for (final f in resume.formulas) {
        buffer.writeln('- $f');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied to clipboard')),
    );
  }

  void _partagerResume() {
    // Pas de dépendance de partage native dans le projet pour l'instant :
    // on copie le contenu et on informe l'utilisateur.
    _copierResume();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing is coming soon — summary copied instead')),
    );
  }

  Future<void> _ajouterAuPlanner() async {
    final resume = _resume;
    if (resume == null) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('planner_tasks').insert({
        'user_id': user.id,
        'subject_id': resume.subjectId,
        'title': 'Review: ${resume.title}',
        'source_type': 'summary',
        'source_id': resume.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your planner')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to planner: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _genererQuizDepuisResume() {
    final resume = _resume;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateQuizScreen(
          initialSubjectId: resume?.subjectId,
          initialDocumentIds: resume?.documentIds,
        ),
      ),
    );
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 222, 229, 251),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.subjectName,
            style: const TextStyle(fontWeight: FontWeight.w700, color: primaryNavy),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy_outlined, color: primaryNavy),
          onPressed: _copierResume,
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: primaryNavy),
          onPressed: _partagerResume,
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Color background = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryNavy),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildKeyIdeas(Summary resume) {
    if (resume.keyIdeas.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      title: '💡 Key Ideas',
      background: const Color(0xFFF3F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: resume.keyIdeas.map((idea) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 15, color: primaryNavy)),
                Expanded(
                  child: Text(idea, style: const TextStyle(fontSize: 14.5, color: primaryNavy, height: 1.35)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDefinitions(Summary resume) {
    if (resume.definitions.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      title: '📖 Definitions',
      background: const Color(0xFFF3F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: resume.definitions.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['term'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy),
                ),
                const SizedBox(height: 4),
                Text(
                  d['definition'] ?? '',
                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormulas(Summary resume) {
    if (resume.formulas.isEmpty) return const SizedBox.shrink();
    return _buildSectionCard(
      title: 'Σ Important Formulas',
      background: const Color.fromARGB(255, 230, 237, 251),
      child: Column(
        children: resume.formulas.map((f) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              f,
              style: const TextStyle(fontWeight: FontWeight.w600, color: primaryNavy),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _genererQuizDepuisResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.quiz_outlined, color: Colors.white, size: 18),
                label: const Text(
                  'Generate Quiz from this',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _ajouterAuPlanner,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_today_outlined, color: primaryNavy, size: 16),
                label: const Text(
                  'Add to Planner',
                  style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        Text(
                          'Summary: ${_resume!.title}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
                        ),
                        _buildKeyIdeas(_resume!),
                        _buildDefinitions(_resume!),
                        _buildFormulas(_resume!),
                        _buildActions(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: (_chargement || _erreur != null) ? null : _buildBottomNav(),
    );
  }
}