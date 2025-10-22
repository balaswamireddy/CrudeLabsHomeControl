import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _supabaseClient.auth.signUp(
      email: email,
      password: password,
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }

  bool isAuthenticated() {
    return _supabaseClient.auth.currentUser != null;
  }

  Stream<AuthState> authStateChanges() {
    return _supabaseClient.auth.onAuthStateChange;
  }
}
