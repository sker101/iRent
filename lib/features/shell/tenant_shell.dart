import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../messages/messages_screen.dart';
import '../rooms/rooms_list_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../tenant_dashboard/my_room_screen.dart';
import 'tenant_profile_tab.dart';

// ─── Tenant shell (logged-in) ─────────────────────────────────────────────
// Tabs: Explore | Wishlist | Messages | Profile

class TenantShell extends ConsumerStatefulWidget {
  const TenantShell({super.key});

  @override
  ConsumerState<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends ConsumerState<TenantShell> {
  int _index = 0;

  static final _pages = [
    const RoomsListScreen(),
    const WishlistScreen(),
    const MyRoomScreen(),
    const MessagesScreen(),
    const TenantProfileTab(),
  ];

  static const _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.explore_outlined),
      activeIcon: Icon(Icons.explore),
      label: 'Explore',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite_outline),
      activeIcon: Icon(Icons.favorite),
      label: 'Wishlist',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.vpn_key_outlined),
      activeIcon: Icon(Icons.vpn_key),
      label: 'My Room',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      activeIcon: Icon(Icons.chat_bubble),
      label: 'Messages',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _NavBar(
        currentIndex: _index,
        items: _items,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ─── Guest shell (not logged in) ─────────────────────────────────────────
// Tabs: Explore | Wishlist | Messages | Login

class GuestShell extends ConsumerStatefulWidget {
  const GuestShell({super.key});

  @override
  ConsumerState<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends ConsumerState<GuestShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        activeIcon: Icon(Icons.explore),
        label: 'Explore',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.favorite_outline),
        activeIcon: Icon(Icons.favorite),
        label: 'Wishlist',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        activeIcon: Icon(Icons.chat_bubble),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.login_outlined),
        activeIcon: Icon(Icons.login),
        label: 'Login',
      ),
    ];

    // For guest: tapping Wishlist, Messages or Login redirects to login
    void onTap(int i) {
      if (i == 0) {
        setState(() => _index = 0);
      } else {
        context.push(AppRoutes.login);
      }
    }

    return Scaffold(
      body: IndexedStack(
        index: 0,
        children: [const RoomsListScreen(key: Key('guest-explore'))],
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _index,
        items: items,
        onTap: onTap,
      ),
    );
  }
}

// ─── Shared styled nav bar ────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        items: items,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withValues(alpha: 0.5),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
