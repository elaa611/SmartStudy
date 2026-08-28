import 'package:flutter/material.dart';
import 'package:smart_study/services/auth.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();

  String? _educationLevel = 'High School';
  String? _academicYear = '1st Year';

  final List<String> _educationLevels = [
    'High School',
    'Bachelor',
    'Master',
    'PhD',
  ];

  final List<String> _academicYears = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    'Graduate',
  ];

  static const Color primaryNavy = Color(0xFF0B1F5C);

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryNavy),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _institutionController.dispose();
    _fieldOfStudyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 10),
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
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      // foregroundDecoration pour avoir le cadre au dessus de l'image
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color.fromARGB(255, 133, 141, 164),
                          width: 1.5,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/logoUpd.png',
                        width: double
                            .infinity, // prend toute la largeur disponible
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Study smart, not hard !',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                        fontFamily: 'Pacifico',
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Create your account to start learning smarter.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pacifico',
                        color: Color.fromARGB(136, 8, 6, 6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 44),

                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 13),

                  _fieldLabel('Full Name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(hintText: 'Asma Ben Ahmed'),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Email Adress'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(hintText: 'asma@example.com'),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        onPressed: () => {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Confirm Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _inputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        onPressed: () => {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          }),
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    'Academic Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 13),

                  _fieldLabel('Education Level'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    //crée un menu déroulant dans un formulaire
                    initialValue: _educationLevel, //valeur actuellement sélectionnée
                    decoration: _inputDecoration(),
                    // on doit transformer chaque élément de cette liste en DropdownMenuItem
                    items:
                        _educationLevels //liste des choix disponibles
                            .map(
                              // pour chaque élément de la liste
                              (level) => DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              ),
                            ) //transforme chaque niveau en DropdownMenuItem
                            .toList(),
                    // map() retourne un objet Iterable, mais DropdownBuuttonFormField attend une liste de DropdownMenuItem
                    onChanged: (value) {
                      //se déclenche quand l'utilisateur choisit une option
                      setState(() {
                        //met à jour l'interface
                        _educationLevel = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Institution Name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _institutionController,
                    decoration: _inputDecoration(
                      hintText: 'e.g: Higher Institute of Computer Science',
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Institution Name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _fieldOfStudyController,
                    decoration: _inputDecoration(
                      hintText: 'e.g: Computer Science',
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Academic Year'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _academicYear,
                    decoration: _inputDecoration(),
                    items: _academicYears
                        .map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ),
                        ) //transforme chaque niveau en DropdownMenuItem
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        //met à jour l'interface
                        _academicYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        // récupération des informations saisies:
                        final fullName = _nameController.text.trim();
                        final email = _emailController.text.trim();
                        final password = _passwordController.text;
                        final confirmPassword = _confirmPasswordController.text;
                        final institution = _institutionController.text.trim();
                        final fieldOfStudy = _fieldOfStudyController.text
                            .trim();

                        if (password != confirmPassword) {
                          // si les mdp différents : afficher un SnackBar en bas de l'écran.
                          ScaffoldMessenger.of(context).showSnackBar(
                            //context permet de savoir où afficher le SnackBar
                            SnackBar(content: Text('Passwords do not match')),
                          );
                          return;
                        }
                        try {
                          // Appeler le service Supabase
                          await AuthService().signUp(
                            email: email,
                            password: password,
                            fullName: fullName,
                            educationLevel: _educationLevel!,
                            institution: institution,
                            fieldOfStudy: fieldOfStudy,
                            academicYear: _academicYear!,
                          );

                          // Succès
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account created successfully!'),
                            ),
                          );
                        } catch (e) {
                          // Erreur, mounted càd si la page n'existe plus, ne continue pas 
                          if (!mounted) return;

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // OR divider
                  // -------------- OR --------------
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Already have an account?',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color.fromARGB(255, 33, 32, 32),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign In instead',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2A6DF4),
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
    );
  }
}
