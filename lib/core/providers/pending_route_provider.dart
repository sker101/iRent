import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores the property ID + property object that a guest tapped before logging in.
/// After login/signup the router reads this and redirects to the room.
class PendingRoute {
  const PendingRoute({required this.propertyId, this.propertyExtra});
  final String propertyId;
  final dynamic propertyExtra; // The full Property object if available
}

class PendingRouteNotifier extends Notifier<PendingRoute?> {
  @override
  PendingRoute? build() => null;

  void set(PendingRoute route) => state = route;
  void clear() => state = null;
}

final pendingRouteProvider =
    NotifierProvider<PendingRouteNotifier, PendingRoute?>(
  PendingRouteNotifier.new,
);
