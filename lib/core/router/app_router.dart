import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../features/auth/google_login_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/properties/add_property_screen.dart';
import '../../features/rooms/room_detail_screen.dart';
import '../../features/shell/landlord_dalali_shell.dart';
import '../../features/shell/tenant_shell.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';

class AppRoutes {
  static const login = '/auth/login';
  static const completeProfile = '/auth/complete-profile';
  // Shell roots (each role now has ONE route that contains its bottom-nav shell)
  static const tenantHome = '/tenant';
  static const landlordHome = '/landlord';
  static const dalaliHome = '/dalali';
  // Shared
  static const rooms = '/rooms';
  static const roomDetail = '/rooms/:id';
  static const addProperty = '/properties/add';
}

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(appUserProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

final routerNotifierProvider =
    Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: AppRoutes.rooms,
    refreshListenable: notifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const GoogleLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (_, _) => const CompleteProfileScreen(),
      ),

      // ── Guest / Tenant shell (rooms list with bottom nav) ─────────────
      GoRoute(
        path: AppRoutes.rooms,
        builder: (_, _) => const GuestShell(),
      ),

      // ── Tenant authenticated shell ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.tenantHome,
        builder: (_, _) => const TenantShell(),
      ),

      // ── Landlord shell ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.landlordHome,
        builder: (_, _) => const LandlordDalaliShell(),
      ),

      // ── Dalali shell ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.dalaliHome,
        builder: (_, _) => const LandlordDalaliShell(),
      ),

      // ── Add property (shared) ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.addProperty,
        builder: (_, state) {
          final extra = state.extra;
          final propertyToEdit = extra is Property ? extra : null;
          return AddPropertyScreen(propertyToEdit: propertyToEdit);
        },
      ),

      // ── Room detail (shared) ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.roomDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final property = state.extra as Property?;
          return RoomDetailScreen(propertyId: id, property: property);
        },
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final session = ref.read(currentSessionProvider);
  final appUserAsync = ref.read(appUserProvider);

  final path = state.uri.path;
  final isAuthPath = path.startsWith('/auth');

  // ── Not signed in: allow rooms (guest shell) and login page ───────────
  if (session == null) {
    if (path == AppRoutes.login || path == AppRoutes.rooms) return null;
    // Any other protected path → back to rooms (guest shell)
    return AppRoutes.rooms;
  }

  // ── Still fetching profile ────────────────────────────────────────────
  if (appUserAsync.isLoading && !appUserAsync.hasValue) return null;

  final profile = appUserAsync.value;

  // ── Signed in, but no profile row yet → complete profile ──────────────
  if (profile == null) {
    if (path == AppRoutes.completeProfile) return null;
    return AppRoutes.completeProfile;
  }

  // ── Signed in with profile: bounce away from auth screens ─────────────
  if (isAuthPath) return _homePath(profile.role);

  // ── Signed in tenant hitting the guest rooms page → go to tenant home ─
  if (path == AppRoutes.rooms && profile.role == UserRole.tenant) {
    return AppRoutes.tenantHome;
  }

  // ── Landlord/Dalali hitting rooms page → go to their home ─────────────
  if (path == AppRoutes.rooms &&
      (profile.role == UserRole.landlord ||
          profile.role == UserRole.dalali ||
          profile.role == UserRole.admin)) {
    return _homePath(profile.role);
  }

  return null;
}

String _homePath(UserRole role) {
  switch (role) {
    case UserRole.tenant:
      return AppRoutes.tenantHome;
    case UserRole.dalali:
      return AppRoutes.dalaliHome;
    case UserRole.landlord:
      return AppRoutes.landlordHome;
    case UserRole.admin:
      return AppRoutes.landlordHome;
  }
}
