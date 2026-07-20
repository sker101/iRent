import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../models/property.dart';

// ── Amenity display catalogue ──────────────────────────────────────────────

const _amenityMeta = {
  'wifi':             ('WiFi',            Icons.wifi,              Colors.blue),
  'electricity':      ('Electricity',     Icons.bolt,              Colors.orange),
  'water':            ('Water',           Icons.water_drop,        Colors.lightBlue),
  'parking':          ('Parking',         Icons.local_parking,     Colors.teal),
  'security_guard':   ('Security Guard',  Icons.security,          Colors.indigo),
  'cctv':             ('CCTV',            Icons.videocam,          Colors.purple),
  'air_conditioning': ('Air Conditioning',Icons.ac_unit,           Colors.cyan),
  'fan':              ('Fan',             Icons.air,               Colors.blueGrey),
  'private_bathroom': ('Private Bathroom',Icons.shower,            Colors.brown),
  'shared_bathroom':  ('Shared Bathroom', Icons.bathtub,           Colors.brown),
  'kitchen':          ('Kitchen',         Icons.kitchen,           Colors.deepOrange),
  'furnished':        ('Furnished',       Icons.chair,             Colors.amber),
  'balcony':          ('Balcony',         Icons.deck,              Colors.green),
  'garden':           ('Garden',          Icons.park,              Colors.green),
  'generator':        ('Generator',       Icons.electrical_services, Colors.red),
};

// ── Screen ─────────────────────────────────────────────────────────────────

class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.propertyId,
    this.property,
  });

  final String propertyId;
  final Property? property;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  int _durationMonths = 1;
  bool _reserving = false;

  // Platform fee rate: 5% of 1 month's rent
  double _platformFee(double price) => price * 0.05;
  // Gateway fee: 3.5% of platform fee
  double _gatewayFee(double price) => _platformFee(price) * 0.035;
  // Total to pay online
  double _totalOnline(double price) => _platformFee(price) + _gatewayFee(price);

  // ── Reserve ────────────────────────────────────────────────────────────

  Future<void> _reserve(Property p) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _reserving = true);

    try {
      final client = Supabase.instance.client;

      // 1 — Insert booking
      await client.from('bookings').insert({
        'property_id': p.id,
        'tenant_id': user.id,
        'landlord_id': p.id, // placeholder — real owner resolving comes with real auth
        'duration_months': _durationMonths,
        'rent_amount': p.price,
        'reservation_fee': _platformFee(p.price),
        'dalali_fee': 0,
        'status': 'reserved',
        'reserved_at': DateTime.now().toIso8601String(),
      });

      // 2 — Mark property as reserved → removes from live listing
      await client
          .from('properties')
          .update({'status': 'reserved'})
          .eq('id', p.id);

      if (!mounted) return;

      // 3 — Show success
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Room Reserved!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You have reserved "${p.title}".', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Total paid: TSH ${_fmt(_totalOnline(p.price))}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'The room will appear in your dashboard under "My Rooms".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop(); // back to listing/dashboard
              },
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.property;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final images = p.imageUrls;
    final lat = p.latitude ?? -6.7924;
    final lng = p.longitude ?? 39.2083;
    final isAlreadyReserved = p.status == 'reserved';

    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Photo Gallery ──────────────────────────────────────────
            if (images.isNotEmpty) ...[
              SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemCount: images.length,
                      itemBuilder: (_, i) => Image.network(
                        images[i], fit: BoxFit.cover, width: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 16, left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${images.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_currentImageIndex > 0)
                      _ArrowButton(
                        alignment: Alignment.centerLeft,
                        icon: Icons.arrow_back_ios,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                    if (_currentImageIndex < images.length - 1)
                      _ArrowButton(
                        alignment: Alignment.centerRight,
                        icon: Icons.arrow_forward_ios,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: images.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _pageController.animateToPage(i,
                        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _currentImageIndex == i ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(images[i]), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              Container(
                height: 240, color: cs.surfaceContainerHigh,
                child: Center(child: Icon(Icons.apartment_rounded, size: 64, color: cs.outlineVariant)),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ─────────────────────────────────────────
                  Text(p.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [p.ward, p.district, p.region]
                              .whereType<String>()
                              .join(', '),
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TSH ${_fmt(p.price)} / month',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAlreadyReserved
                              ? Colors.orange.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAlreadyReserved
                                ? Colors.orange.shade300
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          isAlreadyReserved ? 'Reserved' : 'Available',
                          style: TextStyle(
                            color: isAlreadyReserved
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Room Info Chips ─────────────────────────────────
                  Wrap(
                    spacing: 10, runSpacing: 8,
                    children: [
                      _Chip(icon: Icons.bed, label: '${p.bedrooms} Bed'),
                      _Chip(icon: Icons.bathtub, label: '${p.bathrooms} Bath'),
                      _Chip(icon: Icons.home_work_outlined, label: p.roomTypeLabel),
                      if (p.furnished)
                        const _Chip(icon: Icons.chair, label: 'Furnished'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Uploader Profile Card ───────────────────────────
                  if (p.uploaderName != null) ...[
                    _UploaderCard(
                      name: p.uploaderName!,
                      role: p.uploaderRole ?? 'Landlord',
                      isReserved: isAlreadyReserved,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Monthly Utilities ───────────────────────────────
                  _CardSection(
                    icon: Icons.bolt,
                    iconColor: Colors.orange,
                    title: 'Monthly Utility Costs',
                    child: Column(
                      children: [
                        _UtilityDisplayRow(
                          icon: Icons.bolt,
                          iconColor: Colors.orange,
                          label: 'Electricity (LUKU)',
                          cost: p.electricityCost,
                          note: p.electricityNote,
                        ),
                        const SizedBox(height: 10),
                        _UtilityDisplayRow(
                          icon: Icons.water_drop,
                          iconColor: Colors.blue,
                          label: 'Water (DAWASA)',
                          cost: p.waterCost,
                          note: p.waterNote,
                        ),
                        const SizedBox(height: 10),
                        _UtilityDisplayRow(
                          icon: Icons.delete_outline,
                          iconColor: Colors.grey,
                          label: 'Waste Collection',
                          cost: p.wasteCost,
                          note: p.wasteNote,
                        ),
                        const SizedBox(height: 10),
                        _UtilityDisplayRow(
                          icon: Icons.security,
                          iconColor: Colors.indigo,
                          label: 'Security',
                          cost: p.securityCost,
                          note: p.securityNote,
                        ),
                        if (p.totalMonthlyUtilities > 0) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Est. Total Utilities / month',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('TSH ${_fmt(p.totalMonthlyUtilities)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Utilities are NOT included in the online reservation. Arranged & paid directly to the landlord/utility provider each month.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Description ─────────────────────────────────────
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    Text('About this room',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(p.description!,
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.8), height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // ── Amenities ───────────────────────────────────────
                  if (p.amenities.isNotEmpty) ...[
                    Text('Amenities',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: p.amenities.map((id) {
                        final meta = _amenityMeta[id];
                        final label = meta?.$1 ?? id;
                        final icon = meta?.$2 ?? Icons.check_circle_outline;
                        final color = meta?.$3 ?? Colors.grey;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: color),
                              const SizedBox(width: 6),
                              Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Map ─────────────────────────────────────────────
                  Text('Location',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                            userAgentPackageName: 'com.irent.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lng),
                                width: 40, height: 40,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Reservation Cost Estimate ───────────────────────
                  _CardSection(
                    icon: Icons.monetization_on_outlined,
                    iconColor: cs.primary,
                    title: 'Reservation Cost Estimate',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Duration picker
                        const Text('How many months?',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [1, 3, 6, 12].map((mo) {
                            final sel = _durationMonths == mo;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _durationMonths = mo),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: sel ? cs.primary : Colors.transparent,
                                    border: Border.all(
                                      color: sel ? cs.primary : cs.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('$mo mo',
                                      style: TextStyle(
                                          color: sel ? cs.onPrimary : cs.onSurface,
                                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Online payment breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.phone_android, size: 14),
                                  SizedBox(width: 6),
                                  Text('PAY NOW ONLINE (to reserve)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _CostRow(
                                label: 'Platform Service Fee (5% × 1 mo rent)',
                                value: 'TSH ${_fmt(_platformFee(p.price))}',
                              ),
                              const SizedBox(height: 6),
                              _CostRow(
                                label: 'Gateway Fee (3.5% of platform fee)',
                                value: 'TSH ${_fmt(_gatewayFee(p.price))}',
                              ),
                              const Divider(height: 20),
                              _CostRow(
                                label: 'Total to Pay Online',
                                value: 'TSH ${_fmt(_totalOnline(p.price))}',
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Cash breakdown
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.06),
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.money, size: 14, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text('PAY CASH TO LANDLORD (at move-in)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _CostRow(
                                label: 'Monthly Rent',
                                value: 'TSH ${_fmt(p.price)}',
                              ),
                              if (p.totalMonthlyUtilities > 0) ...[
                                const SizedBox(height: 6),
                                _CostRow(
                                  label: 'Estimated Utilities / month',
                                  value: 'TSH ${_fmt(p.totalMonthlyUtilities)}',
                                ),
                              ],
                              const Divider(height: 20),
                              _CostRow(
                                label: 'Total / month (rent + utilities)',
                                value: 'TSH ${_fmt(p.price + p.totalMonthlyUtilities)}',
                                bold: true,
                              ),
                              const SizedBox(height: 6),
                              _CostRow(
                                label: 'Total for $_durationMonths month(s)',
                                value: 'TSH ${_fmt((p.price + p.totalMonthlyUtilities) * _durationMonths)}',
                                bold: true,
                                color: Colors.green.shade700,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'iRent takes NO cut from rent. 100% of rent goes to the landlord.',
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Sticky Reserve Button ──────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: isAlreadyReserved
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('This room has been reserved',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              )
            : FilledButton.icon(
                onPressed: _reserving ? null : () => _reserve(p),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _reserving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_open),
                label: Text(
                  _reserving
                      ? 'Reserving…'
                      : 'Reserve Now — TSH ${_fmt(_totalOnline(widget.property?.price ?? 0))}',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${NumberFormat('#,###').format(v / 1000000)}M';
    if (v >= 1000) return NumberFormat('#,###').format(v.round());
    return v.toStringAsFixed(0);
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.alignment, required this.icon, required this.onTap});
  final AlignmentGeometry alignment;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _UploaderCard extends StatelessWidget {
  const _UploaderCard({
    required this.name,
    required this.role,
    required this.isReserved,
  });

  final String name;
  final String role;
  final bool isReserved;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primary.withValues(alpha: 0.2),
                foregroundColor: cs.primary,
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 16, color: Colors.green.shade600),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.toUpperCase() == 'DALALI' ? 'Dalali' : 'Landlord',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 20, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isReserved 
                      ? 'Contact info unlocked! Tap to chat or call.'
                      : 'Contact info hidden. Reserve to unlock phone & chat.',
                    style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _UtilityDisplayRow extends StatelessWidget {
  const _UtilityDisplayRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.cost,
    required this.note,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final double cost;
  final String note;

  @override
  Widget build(BuildContext context) {
    final hasCharge = cost > 0;
    final valueText = hasCharge ? 'TSH ${_fmt(cost)}/mo' : 'No charge';
    final valueColor = hasCharge ? Colors.orange.shade700 : Colors.green.shade700;

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(note,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(valueText,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = color ?? cs.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: textColor.withValues(alpha: bold ? 1.0 : 0.75),
                  fontSize: 13)),
        ),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: textColor,
                fontSize: bold ? 14 : 13)),
      ],
    );
  }
}
