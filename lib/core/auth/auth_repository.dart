import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import 'auth_user.dart';

// ─── Abstract contract ────────────────────────────────────────────────────
// Swap MockAuthRepository for SupabaseAuthRepository later — one line change.

abstract class AuthRepository {
  /// Returns the currently signed-in user, or null if not signed in.
  AuthUser? get currentUser;

  /// Sign in with a username and role. Persists across restarts.
  Future<AuthUser> signIn(String username, UserRole role);

  /// Clear the current user. Returns the user to the entry screen.
  Future<void> signOut();
}

// ─── Mock implementation ──────────────────────────────────────────────────

class MockAuthRepository implements AuthRepository {
  static const _usernameKey = 'mock_username';
  static const _roleKey = 'mock_role';
  static const _idKey = 'mock_id';

  // Dummy UUIDs matching supabase/migrations/0004_mock_users.sql
  static const _landlordDummyId = '11111111-1111-1111-1111-111111111111';
  static const _dalaliDummyId = '22222222-2222-2222-2222-222222222222';
  // For tenant we can just generate a random one or use a dummy since tenant doesn't upload
  static const _tenantDummyId = '33333333-3333-3333-3333-333333333333';

  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  /// Call once at startup (before runApp) to restore a persisted session.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final roleStr = prefs.getString(_roleKey);
    final id = prefs.getString(_idKey) ?? _tenantDummyId;
    if (username != null && roleStr != null) {
      _user = AuthUser(
        id: id,
        username: username,
        role: UserRole.fromString(roleStr),
      );
    }
  }

  @override
  Future<AuthUser> signIn(String username, UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    
    String id = _tenantDummyId;
    if (role == UserRole.landlord) id = _landlordDummyId;
    if (role == UserRole.dalali) id = _dalaliDummyId;

    await prefs.setString(_usernameKey, username);
    await prefs.setString(_roleKey, role.name);
    await prefs.setString(_idKey, id);
    _user = AuthUser(id: id, username: username, role: role);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_idKey);
    _user = null;
  }
}

// ─── Riverpod provider ────────────────────────────────────────────────────
// Overridden in main.dart with a real MockAuthRepository instance.
// To swap in Supabase auth later, override with SupabaseAuthRepository instead.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'authRepositoryProvider must be overridden in main.dart',
  );
});
