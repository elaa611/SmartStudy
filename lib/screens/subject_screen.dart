import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

class SubjectScreen extends StatefulWidget {
  final int subjectId; // clé étrangère réelle vers subjects.id
  final String subjectName;
  final IconData subjectIcon;
  final Color subjectColor;

  const SubjectScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.subjectColor,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  // Il vaut mieux stocker le nom + le chemin + l'extension pour afficher la bonne icône plus tard
  final List<Map<String, String>> _courseFiles = [];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final response = await supabase
        .from('documents')
        .select()
        .eq('subject_id', widget.subjectId) // lien fiable par clé étrangère
        .eq(
          'user_id',
          user.id,
        ) // sécurité supplémentaire : jamais les docs d'un autre user
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      _courseFiles
        ..clear()
        ..addAll(
          (response as List).map(
            (doc) => {
              'name': doc['file_name'] as String,
              'path': doc['file_path'] as String,
              'extension': doc['extension'] as String,
              'created_at': (doc['created_at'] ?? '') as String,
            },
          ),
        );
    });
  }

  Future<void> uploadFile() async {
    // Étape 1 : choisir un fichier
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx'],
    );

    //Étape 2 : vérifier l'annulation
    if (result == null || result.files.isEmpty) {
      return;
    }

    //Étape 3 : récupérer les informations
    final pickedFile = result.files.single;
    final fileName = pickedFile.name;
    final filePath = pickedFile.path; // peut être null sur le web
    final extension = fileName.split('.').last.toLowerCase();

    if (filePath == null) return;

    //Étape 4 : commencer l'upload
    setState(() => _isUploading = true);

    try {
      final file = File(filePath);
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('Utilisateur non connecté');
        setState(() => _isUploading = false);
        return;
      }

      final storagePath =
          '${widget.subjectName}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage
          .from('course-documents')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: true,
            ),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'TIMEOUT: storage.upload() n\'a pas répondu en 15s',
              );
            },
          );

      final inserted = await supabase
          .from('documents')
          .insert({
            'subject_id': widget.subjectId,
            'subject': widget.subjectName,
            'file_name': fileName,
            'file_path': storagePath,
            'extension': extension,
            'user_id': user.id,
            'extraction_status': 'pending',
          })
          .select('id')
          .single()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'TIMEOUT: insert documents n\'a pas répondu en 15s',
              );
            },
          );

      if (!mounted) return;

      // 3. Mettre à jour l'UI localement (une seule fois, avec le storagePath)
      setState(() {
        _courseFiles.add({
          'name': fileName,
          'path': storagePath,
          'extension': extension,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      // 4. Déclencher l'extraction du texte en arrière-plan.
      //    On ne fait PAS de "await" ici : on ne bloque pas l'utilisateur,
      //    l'extraction se fait pendant qu'il continue à utiliser l'app.
      //    (le cours restera juste grisé dans GenerateQuizScreen tant que
      //    extraction_status != 'completed')  
      try {
  final response = await supabase.functions.invoke(
    'extract-text',
    body: {'document_id': inserted['id']},
  );

  print('EXTRACT TEXT RESPONSE = ${response.data}');
} catch (e) {
  print('EXTRACT TEXT ERROR = $e');
}
    } on StorageException catch (e) {
      _showError('Erreur upload : ${e.message}');
    } catch (e) {
      _showError('Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  IconData _iconForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color.fromARGB(255, 230, 21, 6);
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  String _lastOpenedLabel(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Last opened at --';

    final date = DateTime.tryParse(isoDate);
    if (date == null) return 'Last opened at --';

    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(local.year, local.month, local.day);

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (thatDay == today) {
      return 'Last opened at Today, $time';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (thatDay == yesterday) {
      return 'Last opened at Yesterday, $time';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Last opened at ${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  List<Map<String, String>> get _filteredFiles {
    if (_query.isEmpty)
      return _courseFiles; // Si l'utilisateur ne recherche rien → afficher tous les fichiers.
    return _courseFiles
        .where(
          (file) =>
              (file['name'] ?? '').toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
  }

  Future<void> _openFile(String filePath) async {
    try {
      final supabase = Supabase.instance.client;

      debugPrint('==============================');
      debugPrint('OPEN FILE');
      debugPrint('FILE PATH = $filePath');
      debugPrint('BUCKET = course-documents');

      final signedUrl = await supabase.storage
          .from('course-documents')
          .createSignedUrl(filePath, 3600);

      debugPrint('SIGNED URL = $signedUrl');

      final uri = Uri.parse(signedUrl);

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on StorageException catch (e) {
      debugPrint('==============================');
      debugPrint('STORAGE ERROR');
      debugPrint('MESSAGE = ${e.message}');
      debugPrint('STATUS = ${e.statusCode}');
      debugPrint('ERROR = $e');

      _showError('Erreur Storage : ${e.message}');
    } catch (e) {
      debugPrint('OPEN FILE ERROR = $e');
      _showError('Erreur : $e');
    }
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
          hintText: 'Search documents..',
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filesToShow = _filteredFiles;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1F5C),
        foregroundColor: Colors.white,
        title: Text(
          widget.subjectName.toUpperCase(),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My courses',
              style: TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002B5B),
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 28),
            Expanded(
              child: filesToShow.isEmpty
                  ? const Center(
                      child: Text(
                        'No courses uploaded yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filesToShow.length,
                      itemBuilder: (context, index) {
                        final file = filesToShow[index];
                        final ext = file['extension'] ?? '';
                        final extColor = _colorForExtension(ext);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openFile(file['path']!),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                //child bch ywali column fi westou row et boutton de résumé (get a summary! )
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Icône + badge d'extension
                                        Container(
                                          width: 75,
                                          height: 80,

                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                              255,
                                              239,
                                              238,
                                              238,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Icon(
                                                _iconForExtension(ext),
                                                color: extColor,
                                                size: 25,
                                              ),
                                              const SizedBox(height: 10),
                                              Container(
                                                width: double.infinity,

                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: extColor,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  ext.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Nom + dernière ouverture
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file['name'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0B1F5C),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _lastOpenedLabel(
                                                  file['created_at'],
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF5B6B8C),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      //Crée un bouton flottant avec une icône + un texte.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading
            ? null
            : uploadFile, //Si _isUploading == true, le bouton est désactivé.
        backgroundColor: const Color(0xFF2A6DF4),
        icon:
            _isUploading // icon change selon l'état : _isUploading == true → affiche un cercle de chargement sinon icon l3adi
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file, color: Colors.white),
        label: Text(
          _isUploading ? 'Upload...' : 'Upload File',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
