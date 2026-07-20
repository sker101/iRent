import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_user.dart';

// ─── Raw Supabase client ───────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── Auth state stream ─────────────────────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// ─── Current Session ──────────────────────────────────────────────────────

final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (s) => s.session);
});

// ─── App user (users table row) ───────────────────────────────────────────

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  // Re-run whenever auth state changes.
  final authState = ref.watch(authStateProvider);
  final session = authState.whenOrNull(data: (s) => s.session);
  if (session == null) return null;

  final uid = session.user.id;
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('users')
        .select()
        .eq('auth_id', uid)
        .maybeSingle();
    if (response == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(response));
  } catch (_) {
    return null;
  }
});

// ─── Auth notifier ────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  SupabaseClient get _client => ref.read(supabaseClientProvider);

  @override
  Future<void> build() async {}

  /// Sign in with Google using OAuth.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'irent://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    });
  }

  /// Insert a new row in the users table for the currently signed-in user.
  Future<AppUser> createUser({
    required String fullName,
    required String? phone,
    required UserRole role,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final email = session.user.email ?? '';
    final authId = session.user.id;

    final newUser = AppUser(
      id: '', // will be assigned by Supabase
      authId: authId,
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      verified: false,
      createdAt: DateTime.now(),
    );

    final response = await _client
        .from('users')
        .insert(newUser.toInsertJson())
        .select()
        .single();

    // Invalidate the appUserProvider so it re-fetches.
    ref.invalidate(appUserProvider);

    return AppUser.fromJson(Map<String, dynamic>.from(response));
  }

  /// Sign the current user out.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signOut();
      ref.invalidate(appUserProvider);
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
