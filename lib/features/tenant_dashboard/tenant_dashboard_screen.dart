import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../models/property.dart';
import '../rooms/room_detail_screen.dart';
import 'views/my_room_view.dart';
import 'views/profile_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TENANT DASHBOARD SCREEN
// A Scaffold with a beautifully-designed Drawer acting as the main navigation.
// Tabs: Dashboard | My Room | Saved | Messages | Profile
// ─────────────────────────────────────────────────────────────────────────────

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Current page index: 0=Dashboard, 1=My Room, 2=Saved, 3=Messages, 4=Profile
  int _selectedIndex = 0;

  late Future<List<Property>> _myRoomsFuture;

  @override
  void initState() {
    super.initState();
    _loadMyRooms();
  }

  void _loadMyRooms() {
    final user = ref.read(appUserProvider).value;
    if (user == null) {
      _myRoomsFuture = Future.value([]);
      return;
    }
    setState(() {
      _myRoomsFuture = _fetchMyRooms(user.id);
    });
  }

  Future<List<Property>> _fetchMyRooms(String tenantId) async {
    final res = await Supabase.instance.client
        .from('bookings')
        .select(
          'property_id, status, reserved_at, properties(*, property_images(url, sort_order), uploader:users!owner_id(full_name, role))',
        )
        .eq('tenant_id', tenantId)
        .inFilter('status', ['reserved', 'occupied'])
        .order('reserved_at', ascending: false);

    final properties = <Property>[];
    for (final row in res as List) {
      final propJson = row['properties'];
      if (propJson != null) {
        properties.add(Property.fromJson(Map<String, dynamic>.from(propJson as Map)));
      }
    }
    return properties;
  }

  // ── Page labels & icons ────────────────────────────────────────────────────

  static const _pageLabels = ['Dashboard', 'My Room', 'Saved', 'Messages', 'Profile'];
  static const _pageIcons = [
    Icons.dashboard_rounded,
    Icons.apartment_rounded,
    Icons.bookmark_outline_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];
  static const _pageIconsActive = [
    Icons.dashboard_rounded,
    Icons.apartment_rounded,
    Icons.bookmark_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  // ── App bar titles ────────────────────────────────────────────────────────

  String get _title => _pageLabels[_selectedIndex];

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final user = ref.watch(appUserProvider).value;
    switch (_selectedIndex) {
      case 0:
        return _DashboardView(
          onNavigate: (i) => setState(() => _selectedIndex = i),
          myRoomsFuture: _myRoomsFuture,
          onRefresh: _loadMyRooms,
        );
      case 1:
        return MyRoomView(future: _myRoomsFuture);
      case 2:
        return const _PlaceholderView(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved Rooms',
          subtitle: 'Rooms you save will appear here.',
          comingSoon: true,
        );
      case 3:
        return const _PlaceholderView(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Messages',
          subtitle: 'Chat with landlords & dalalis after booking.',
          comingSoon: true,
        );
      case 4:
        return ProfileView(fullName: user?.fullName ?? '');
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,

      // ── Premium Drawer ────────────────────────────────────────────────────
      drawer: _TenantDrawer(
        selectedIndex: _selectedIndex,
        fullName: user?.fullName ?? 'Tenant',
        labels: _pageLabels,
        icons: _pageIcons,
        activeIcons: _pageIconsActive,
        onSelect: (i) {
          setState(() => _selectedIndex = i);
          Navigator.of(context).pop(); // close drawer
        },
        onSignOut: () async {
          await ref.read(authNotifierProvider.notifier).signOut();
          if (context.mounted) context.go(AppRoutes.rooms);
        },
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _HamburgerIcon(isDark: isDark),
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            _title,
            key: ValueKey(_title),
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: cs.onSurface),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withValues(alpha: 0.2),
                child: Text(
                  (user?.fullName ?? '?')[0].toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _buildBody(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HAMBURGER ICON — Custom animated 3-bar hamburger
// ─────────────────────────────────────────────────────────────────────────────

class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 2.5, width: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 5),
        Container(height: 2.5, width: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 5),
        Container(height: 2.5, width: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER
// ─────────────────────────────────────────────────────────────────────────────

class _TenantDrawer extends StatelessWidget {
  const _TenantDrawer({
    required this.selectedIndex,
    required this.fullName,
    required this.labels,
    required this.icons,
    required this.activeIcons,
    required this.onSelect,
    required this.onSignOut,
  });

  final int selectedIndex;
  final String fullName;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> activeIcons;
  final void Function(int) onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Drawer(
      width: 290,
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade700,
                    Colors.green.shade500,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'iRent',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // User avatar + name
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Tenant', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Navigation Items ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: labels.length,
                itemBuilder: (context, i) {
                  final isSelected = selectedIndex == i;
                  final isComingSoon = i == 2 || i == 3; // Saved, Messages

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? activeIcons[i] : icons[i],
                                color: isSelected
                                    ? Colors.green.shade700
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
                                    color: isSelected
                                        ? Colors.green.shade700
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isComingSoon)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Soon',
                                    style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (isSelected && !isComingSoon)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Divider ───────────────────────────────────────────────────
            const Divider(height: 1, indent: 24, endIndent: 24),
            const SizedBox(height: 12),

            // ── Browse Rooms ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).pop();
                    GoRouter.of(context).push(AppRoutes.rooms);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 22),
                        const SizedBox(width: 14),
                        const Text('Browse Rooms', style: TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Sign Out ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSignOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
                        const SizedBox(width: 14),
                        const Text('Sign Out', style: TextStyle(fontSize: 15, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD VIEW (index 0)
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardView extends ConsumerWidget {
  const _DashboardView({
    required this.onNavigate,
    required this.myRoomsFuture,
    required this.onRefresh,
  });

  final void Function(int) onNavigate;
  final Future<List<Property>> myRoomsFuture;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Welcome Banner ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.fullName ?? 'Tenant',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your home-finding journey starts here.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => GoRouter.of(context).push(AppRoutes.rooms),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Browse Rooms', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Quick Access Grid ─────────────────────────────────────────
          Text('Quick Access', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickCard(
                  icon: Icons.apartment_rounded,
                  label: 'My Room',
                  color: Colors.green,
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickCard(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved',
                  color: Colors.blue,
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickCard(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  color: Colors.purple,
                  onTap: () => onNavigate(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── My Reserved Rooms ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Reserved Rooms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => onNavigate(1),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Property>>(
            future: myRoomsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Error: ${snapshot.error}', style: TextStyle(color: cs.error)),
                );
              }
              final rooms = snapshot.data ?? [];
              if (rooms.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.home_outlined, size: 48, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      Text('No reserved rooms yet.', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Text('Browse and reserve a room to see it here.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }
              return Column(
                children: rooms.map((p) => _ReservedRoomCard(
                  property: p,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RoomDetailScreen(propertyId: p.id, property: p),
                    ));
                  },
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACCESS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER VIEW (for Saved & Messages — coming soon)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: cs.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            if (comingSoon) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text('🚧  Coming in the next phase', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVED ROOM CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ReservedRoomCard extends StatelessWidget {
  const _ReservedRoomCard({required this.property, required this.onTap});
  final Property property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = property;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: p.coverImageUrl != null
                    ? Image.network(p.coverImageUrl!, width: 80, height: 80, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(cs))
                    : _placeholder(cs),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(p.locationLabel,
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('TSH ${_fmt(p.price)}/mo',
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('Reserved',
                              style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 80, height: 80,
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.apartment_rounded, color: cs.outlineVariant),
      );

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
