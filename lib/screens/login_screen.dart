import 'package:flutter/material.dart';
import 'package:smart_study/screens/home_screen.dart';
import 'package:smart_study/services/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';

/*
LoginScreen = l'écran
State = les informations variables de l'écran
*/

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  //"Quand tu crées LoginScreen, utilise _LoginScreenState pour gérer son état."
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  static const Color primaryNavy = Color(0xFF0B1F5C);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold : fournit la structure de base d'une app mobile (appBar, body, floatingActionButton)
    return Scaffold(
      body: SafeArea(
        child: Center(
          // child : huwa l widget qui se trouve à l'intérieur de Center eli huwa l parent
          //permet au contenu de défiler lorsqu'il est trop grand pour l'écran
          child: SingleChildScrollView(
            //EdgeInsets : définir des espaces autour/dans un widget
            //symmetric : même valeur pour les côtés opposés (symétriquement)
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ), //const indique que les parametres sont tjrs fixes
            //container1 le plus grand (blanc)
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
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
                    offset: const Offset(0, 8),
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
                  const SizedBox(height: 20),

                  //ajoute un espace vertical de 20 pixels entre deux widgets cad entre logo et titre
                  Center(
                    child: Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                        fontFamily: 'Pacifico',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Log in to continue your learning journey.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pacifico',
                        color: Color.fromARGB(137, 20, 20, 20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType
                        .emailAddress, //Cela indique à Flutter : Ce champ est destiné à recevoir une adresse email
                    // _emailController.text recupère la valeur de l'email
                    decoration: InputDecoration(
                      hintText: 'ahmed@example.com',
                      prefixIcon: const Icon(
                        Icons.mail_outline,
                        size: 20,
                      ), // ajoute une icône au début du champ
                      filled:
                          true, // active le fond coloré, si false le fillColor ne fonctionne pas
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ), // espace intérieur
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      //bordure de TextField
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  const Text(
                    'Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        //afficher icone à la fin du champ
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Remember me / Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            // sizedbox est comme un boutton
                            // donne une taille précise à la checkbox
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor:
                                  primaryNavy, //la couleur de chckbox lorsqu'elle est cohée
                              onChanged: (value) {
                                setState(() {
                                  //permet à l'écran de se mettre à jour quand cette valeur change
                                  _rememberMe =
                                      value ??
                                      false; //si value est null, utilise false
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Remember Me',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: navigate to forgot password screen
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets
                              .zero, //par défaut, TextButton possède un peu d'espace autour du texte : na7ineh
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          //Flutter réserve normalement une zone assez grande autour d'un bouton pour qu'il soit facile à toucher et donc shrinkWrap permet de réduire cette zone au maximum autour du contenu
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2A6DF4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = _emailController.text;
                        final password = _passwordController.text;

                        if (email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter your email and password.'),
                            ),
                          );
                        return;
                        }

                        try {
                          final response = await _authService.login(
                            email: email,
                            password: password,
                          );

                          if (response.user != null) {
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Login successful!'),
                              ),
                            );
  
                            Navigator.pushReplacement(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => const HomeScreen(),
                               ),
                             );
                          }
                        } on AuthException catch (e) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('An unexpected error occurred: $e'),
                            ),
                          );
                        }
                      },
                      /* 
                      textButton : bouton avec juste de texte
                      elevatedButton : bouton à action principal, généralement avec un fond rempli
                      outlineButton : bouton à action secondaire avec bordure mais sans fond rempli
                      */
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3, // ombre sous le bouton
                      ),
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OR divider
                  // -------------- OR --------------
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      // expanded prend tout l'espace horizontal disponible
                      // divider c une ligne horizontale
                      Padding(
                        // on ne peut pas ajouter l'attribut padding donc, on utilise le widget Padding
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ), //mebin l OR w divider
                        child: Text(
                          'OR',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google sign in
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      // c une variante de OutlineButton qui est un bouton spécialement prévu pour avoir une icône + un texte
                      // .icon fournit directement deux paramètres : icon:... et label:...
                      onPressed: () {
                        // TODO: implement Google sign-in
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          // définit la bordure du bouton
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 26,
                        color: Colors.black87,
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign up
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets
                                .zero, //par défaut, TextButton possède un peu d'espace autour du texte : na7ineh
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            //Flutter réserve normalement une zone assez grande autour d'un bouton pour qu'il soit facile à toucher et donc shrinkWrap permet de réduire cette zone au maximum autour du contenu
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2A6DF4),
                            ),
                          ),
                        ),
                      ],
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
