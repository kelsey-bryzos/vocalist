import '../../../core/supabase/supabase_client.dart';

/// Thin wrapper around Supabase Auth — keeps screens clean.
class AuthService {
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }
}
