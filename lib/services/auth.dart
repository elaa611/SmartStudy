import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String educationLevel,
    required String institution,
    required String fieldOfStudy,
    required String academicYear,
  }) async {
    // 1. Créer le compte dans Supabase Auth
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Account creation failed');
    }

    // 2. Ajouter les informations du profil
    // dans public.users
    await supabase.from('users').insert({
      'id': user.id,
      'user_name': fullName,
      'edu_level': educationLevel,
      'institut_name': institution,
      'study_field': fieldOfStudy,
      'study_year': academicYear,
    });
  }

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    return response;
  }

  // Logout
  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  // Current user
  User? get currentUser => supabase.auth.currentUser;

}