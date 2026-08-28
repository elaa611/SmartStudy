import 'package:flutter/material.dart';
import 'package:smart_study/services/auth.dart';
import 'package:smart_study/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'plan_screen.dart';
import 'study_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color accentBlue = Color(0xFF2A6DF4);
  static const Color background = Color(0xFFF3F5F9);

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  final SupabaseClient _supabase = Supabase.instance.client;

  String studentName = '';
  String studentEmail = '';
  String studentLevel = '';
  String studyYear = '';
  String studyField = '';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _profileService.getCurrentUserProfile();

      print('DATA PROFILE = $data');

      final user = _supabase.auth.currentUser;

      if (data == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        studentName = data['user_name'] ?? '';
        studentEmail = user?.email ?? '';
        studentLevel = data['edu_level'] ?? '';
        studyYear = data['study_year'] ?? '';
        studyField = data['study_field'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du profil : $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Ouvrir le menu
          },
        ),
        backgroundColor: primaryNavy,
        title: Text(
          'SmartStudy',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        /*
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              child: Icon(
                Icons.person,
                size: 20,
                color: primaryNavy.withValues(),
              ),
            ),
          ),
        ],
        */
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: Center(
                  child: Container(
                    width: 380,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(
                            255,
                            205,
                            204,
                            204,
                          ).withValues(),
                          blurRadius: 50,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'My Profile',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryNavy,
                              fontFamily: 'Pacifico',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                foregroundDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      133,
                                      141,
                                      164,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color: primaryNavy.withValues(),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: accentBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.camera_alt_outlined,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {},
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        Center(
                          child: Text(
                            studentName,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Center(
                          child: Text(
                            studentEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color.fromARGB(137, 20, 20, 20),
                            ),
                          ),
                        ),

                        SizedBox(height: 6),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$studyYear - $studyField',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Section : informations du compte
                        const Text(
                          'Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ProfileMenuTile(
                          icon: Icons.person_outline,
                          label: 'Edit Profile',
                          onTap: () {
                            // TODO: navigate to edit profile screen
                          },
                        ),
                        _ProfileMenuTile(
                          icon: Icons.lock_outline,
                          label: 'Change Password',
                          onTap: () {
                            // TODO: navigate to change password screen
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section : préférences
                        const Text(
                          'Preferences',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SwitchListTile(
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _notificationsEnabled = value;
                              });
                            },
                            activeThumbColor: primaryNavy,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: const Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            secondary: const Icon(
                              Icons.notifications_outlined,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Bouton de déconnexion
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await _authService.logout();

                                if (!context.mounted) return;

                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              } on AuthException catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              Icons.logout,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            selectedIndex: 4,
            indicatorColor: const Color.fromARGB(255, 222, 230, 255),

            onDestinationSelected: (index) {
              if (index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
              if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudyScreen()),
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

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
