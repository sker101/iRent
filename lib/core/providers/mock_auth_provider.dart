import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../auth/auth_user.dart';
import '../../models/app_user.dart';

// ─── Notifier ─────────────────────────────────────────────────────────────
// Uses Riverpod 3's Notifier API (StateNotifier was removed in v3).

class MockAuthNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    // Seed initial state from the already-initialised repository.
    return ref.read(authRepositoryProvider).currentUser;
  }

  Future<AuthUser> signIn(String username, UserRole role) async {
    final user = await ref.read(authRepositoryProvider).signIn(username, role);
    state = user;
    return user;
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────
// Exposes AuthUser? — null means not signed in.

final mockAuthProvider = NotifierProvider<MockAuthNotifier, AuthUser?>(
  MockAuthNotifier.new,
);
