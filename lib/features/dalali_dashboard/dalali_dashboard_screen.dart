import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../models/property.dart';

class DalaliDashboardScreen extends ConsumerStatefulWidget {
  const DalaliDashboardScreen({super.key});

  @override
  ConsumerState<DalaliDashboardScreen> createState() =>
      _DalaliDashboardScreenState();
}

class _DalaliDashboardScreenState extends ConsumerState<DalaliDashboardScreen> {
  late Future<List<Property>> _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final user = ref.read(appUserProvider).value;
    if (user == null) {
      _future = Future.value([]);
      return;
    }
    setState(() {
      _future = _loadProperties(user.id);
    });
  }

  Future<List<Property>> _loadProperties(String userId) async {
    final response = await Supabase.instance.client
        .from('properties')
        .select('*, property_images(url, sort_order), uploader:users!owner_id(full_name, role)')
        .eq('dalali_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((j) => Property.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dalali Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.rooms);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(AppRoutes.addProperty);
          if (result == true) {
            _fetch();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Upload Property'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Property>>(
          future: _future,
          builder: (context, snapshot) {
            final properties = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Welcome, ${user?.fullName ?? 'Dalali'} 👋',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your portfolio and connect tenants with landlords.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 24),

                _BrowseRoomsCard(),
                const SizedBox(height: 24),

                Text('Your performance',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.key_rounded,
                        label: 'Successful Deals',
                        value: '0',
                        color: cs.primaryContainer,
                        iconColor: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.home_work_outlined,
                        label: 'Active Listings',
                        value: snapshot.connectionState == ConnectionState.waiting
                            ? '...'
                            : '${properties.length}',
                        color: cs.secondaryContainer,
                        iconColor: cs.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('My Portfolio',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (properties.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'You haven\'t uploaded any properties yet.',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  )
                else
                  ...properties.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.apartment),
                          ),
                          title: Text(p.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${p.roomTypeLabel} • TZS ${p.price}',
                            maxLines: 1,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final result = await context.push(
                                AppRoutes.addProperty,
                                extra: p,
                              );
                              if (result == true) {
                                _fetch();
                              }
                            },
                          ),
                        ),
                      )),
                const SizedBox(height: 80), // Padding for FAB
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrowseRoomsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.rooms),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Browse Rooms',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Find live listings across Tanzania',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
