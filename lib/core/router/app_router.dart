import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../features/auth/google_login_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/dalali_dashboard/dalali_dashboard_screen.dart';
import '../../features/landlord_dashboard/landlord_dashboard_screen.dart';
import '../../features/properties/add_property_screen.dart';
import '../../features/rooms/room_detail_screen.dart';
import '../../features/rooms/rooms_list_screen.dart';
import '../../features/tenant_dashboard/tenant_dashboard_screen.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';

class AppRoutes {
  static const login = '/auth/login';
  static const completeProfile = '/auth/complete-profile';
  static const tenantDashboard = '/dashboard/tenant';
  static const dalaliDashboard = '/dashboard/dalali';
  static const landlordDashboard = '/dashboard/landlord';
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

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

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

      // ── Dashboards ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.tenantDashboard,
        builder: (_, _) => const TenantDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.dalaliDashboard,
        builder: (_, _) => const DalaliDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.landlordDashboard,
        builder: (_, _) => const LandlordDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.addProperty,
        builder: (_, state) {
          final extra = state.extra;
          final propertyToEdit = extra is Property ? extra : null;
          return AddPropertyScreen(propertyToEdit: propertyToEdit);
        },
      ),

      // ── Rooms (shared across roles) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.rooms,
        builder: (_, _) => const RoomsListScreen(),
      ),
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

  // Not signed in
  if (session == null) {
    if (path == AppRoutes.login || path == AppRoutes.rooms) return null;
    return AppRoutes.login;
  }

  // Still fetching the profile
  if (appUserAsync.isLoading && !appUserAsync.hasValue) return null;

  final profile = appUserAsync.value;

  // Signed in, but missing profile
  if (profile == null) {
    if (path == AppRoutes.completeProfile) return null;
    return AppRoutes.completeProfile;
  }

  // Signed in and profile exists, don't allow access to auth screens
  if (isAuthPath) return _dashboardPath(profile.role);

  return null;
}

String _dashboardPath(UserRole role) {
  switch (role) {
    case UserRole.tenant:
      return AppRoutes.tenantDashboard;
    case UserRole.dalali:
      return AppRoutes.dalaliDashboard;
    case UserRole.landlord:
      return AppRoutes.landlordDashboard;
    case UserRole.admin:
      return AppRoutes.tenantDashboard;
  }
}
