import '../../models/app_user.dart';

/// Lightweight identity model used by the mock auth layer.
/// Has only what the UI needs: a display name and a role.
/// The full [AppUser] (with authId, email, etc.) is used by Supabase auth.
class AuthUser {
  const AuthUser({required this.id, required this.username, required this.role});

  final String id;
  final String username;
  final UserRole role;
}
