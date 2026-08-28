import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    // <Map<String, dynamic>?> : type de retour clé String et valeur peut avoir les différents types
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    // data est la variable qu'on stocke le res de la requete select 
    final data = await _supabase 
        .from('users')
        .select()
        .eq('id', user.id)
        .single(); // permet donc de récupérer directement cette ligne sous forme de Map
        // Sans single(), le résultat serait plutôt une liste de Map fiha les données d'un seul user
      
    return data;
  }
}