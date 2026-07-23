import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/providers/pending_route_provider.dart';
import '../../models/property.dart';
import 'room_detail_screen.dart';

// ─── Filter state ─────────────────────────────────────────────────────────

class _Filter {
  final String district;
  final String roomType;
  final double? maxPrice;

  const _Filter({
    this.district = '',
    this.roomType = '',
    this.maxPrice,
  });

  _Filter copyWith({String? district, String? roomType, double? maxPrice, bool clearPrice = false}) =>
      _Filter(
        district: district ?? this.district,
        roomType: roomType ?? this.roomType,
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      );

  bool get isEmpty => district.isEmpty && roomType.isEmpty && maxPrice == null;
}

// ─── Screen ───────────────────────────────────────────────────────────────

class RoomsListScreen extends ConsumerStatefulWidget {
  const RoomsListScreen({super.key});

  @override
  ConsumerState<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends ConsumerState<RoomsListScreen> {
  _Filter _filter = const _Filter();
  late Future<List<Property>> _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    setState(() {
      _future = _loadProperties();
    });
  }

  Future<List<Property>> _loadProperties() async {
    try {
      var query = Supabase.instance.client
          .from('properties')
          .select(
            '*, property_images(url, sort_order), uploader:users!owner_id(full_name, role, phone)',
          )
          // ── KEY FILTER: only show rooms that are available (not reserved/paid) ──
          .eq('status', 'live');

      if (_filter.district.trim().isNotEmpty) {
        query = query.ilike('district', '%${_filter.district.trim()}%');
      }
      if (_filter.roomType.isNotEmpty) {
        query = query.eq('room_type', _filter.roomType);
      }
      if (_filter.maxPrice != null) {
        query = query.lte('price', _filter.maxPrice!);
      }

      final response =
          await query.order('created_at', ascending: false).limit(50);
      debugPrint('Properties query response: $response');
      debugPrint('Response length: ${response.length}');
      return (response as List)
          .map((j) => Property.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading properties: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Rooms'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (session == null)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.login),
              icon: const Icon(Icons.login),
              label: const Text('Log In'),
            )
          else
            IconButton(
              icon: const Icon(Icons.dashboard_rounded),
              tooltip: 'Dashboard',
              onPressed: () => context.push(AppRoutes.login), // It will redirect to dashboard
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // District search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by district…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filter.district.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _filter = _filter.copyWith(district: '');
                              });
                              _fetch();
                            })
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _filter = _filter.copyWith(district: v);
                    });
                  },
                  onSubmitted: (_) => _fetch(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Room type dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filter.roomType.isEmpty ? null : _filter.roomType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: cs.surfaceContainerLowest,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Any type')),
                          DropdownMenuItem(value: 'single', child: Text('Single')),
                          DropdownMenuItem(value: 'double', child: Text('Double')),
                          DropdownMenuItem(value: 'bedsitter', child: Text('Bedsitter')),
                          DropdownMenuItem(value: 'self_contained', child: Text('Self-contained')),
                          DropdownMenuItem(value: 'house', child: Text('House')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filter = _filter.copyWith(roomType: v ?? '');
                          });
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Max price dropdown
                    Expanded(
                      child: DropdownButtonFormField<double?>(
                        value: _filter.maxPrice,
                        decoration: InputDecoration(
                          labelText: 'Max price',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: cs.surfaceContainerLowest,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Any price')),
                          DropdownMenuItem(value: 100000.0, child: Text('≤ 100k')),
                          DropdownMenuItem(value: 200000.0, child: Text('≤ 200k')),
                          DropdownMenuItem(value: 300000.0, child: Text('≤ 300k')),
                          DropdownMenuItem(value: 500000.0, child: Text('≤ 500k')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filter = v == null
                                ? _filter.copyWith(clearPrice: true)
                                : _filter.copyWith(maxPrice: v);
                          });
                          _fetch();
                        },
                      ),
                    ),
                  ],
                ),
                if (!_filter.isEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.filter_list_off, size: 16),
                      label: const Text('Clear filters'),
                      onPressed: () {
                        setState(() {
                          _filter = const _Filter();
                        });
                        _fetch();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<Property>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 48, color: cs.error),
                          const SizedBox(height: 16),
                          Text('Could not load listings.',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: _fetch,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final props = snapshot.data ?? [];
                if (props.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.apartment_rounded,
                            size: 56, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No live listings yet.',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _filter.isEmpty
                              ? 'Check back soon!'
                              : 'Try different filters.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: props.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _PropertyCard(property: props[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Property card ─────────────────────────────────────────────────────────

class _PropertyCard extends ConsumerWidget {
  const _PropertyCard({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final user = ref.read(appUserProvider).value;
          if (user == null) {
            // Guest user: save pending route and show auth bottom sheet
            ref.read(pendingRouteProvider.notifier).set(
                  PendingRoute(propertyId: property.id, propertyExtra: property),
                );
            _showAuthBottomSheet(context);
          } else {
            // Logged in: go straight to room
            context.push('${AppRoutes.rooms}/${property.id}', extra: property);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image or placeholder
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: property.coverImageUrl != null
                  ? Image.network(
                      property.coverImageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          property.roomTypeLabel,
                          style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        property.locationLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                      if (property.furnished) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.chair_outlined,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 3),
                        Text('Furnished',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TZS ${_fmt(property.price)} / month',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: double.infinity,
      color: cs.surfaceContainerHigh,
      child: Center(
        child: Icon(Icons.apartment_rounded,
            size: 56, color: cs.outlineVariant),
      ),
    );
  }
}

void _showAuthBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login_rounded, size: 48, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Sign in to view rooms',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need an account to view full room details and make reservations. Sign in or create a new account to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.login);
                  },
                  child: const Text('Log in / Sign up'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
