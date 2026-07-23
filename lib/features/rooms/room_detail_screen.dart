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
  bool _hasActiveBooking = false;   // true if tenant already has a reserved room
  bool _checkingBooking = true;
  bool _fetchingProperty = false;
  Property? _property;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    if (_property == null) {
      _fetchProperty();
    }
    _checkExistingBooking();
  }

  Future<void> _fetchProperty() async {
    setState(() => _fetchingProperty = true);
    try {
      final res = await Supabase.instance.client
          .from('properties')
          .select('*, property_images(url, sort_order), uploader:users!owner_id(full_name, role, phone)')
          .eq('id', widget.propertyId)
          .single();
          
      if (mounted) {
        setState(() {
          _property = Property.fromJson(res);
          _fetchingProperty = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingProperty = false);
    }
  }

  Future<void> _checkExistingBooking() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) { if (mounted) setState(() => _checkingBooking = false); return; }

      // Find the user row from the users table
      final userRow = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (userRow == null) { if (mounted) setState(() => _checkingBooking = false); return; }

      final tenantId = userRow['id'] as String;

      // Check for any active (reserved or occupied) bookings for this tenant
      final existing = await Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['reserved', 'occupied'])
          .limit(1);

      if (mounted) setState(() {
        _hasActiveBooking = (existing as List).isNotEmpty;
        _checkingBooking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingBooking = false);
    }
  }

  // Fee structure (all % of 1 month's rent)
  double _platformFee(double price) => price * 0.05;          // 5%  iRent fee
  double _gatewayFee(double price) => price * 0.035;          // 3.5% gateway fee
  double _serviceFee(double price) => price * 0.20;           // 20% service / dalali fee
  double _totalOnline(double price) =>                        // 28.5% total
      _platformFee(price) + _gatewayFee(price) + _serviceFee(price);

  // ── Mock Payment Flow ────────────────────────────────────────────────────

  Future<void> _reserve(Property p) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to reserve a room')),
      );
      return;
    }
    // Show payment confirmation sheet first
    await _showMockPaymentSheet(p, user.id);
  }

  Future<void> _showMockPaymentSheet(Property p, String tenantId) async {
    final totalRent = p.price * _durationMonths;
    final fee = _platformFee(p.price);
    final gateway = _gatewayFee(p.price);
    final serviceFee = _serviceFee(p.price);
    final toPay = fee + gateway + serviceFee;
    final startDate = DateTime.now();
    final endDate = DateTime(startDate.year, startDate.month + _durationMonths, startDate.day);
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('dd MMM yyyy');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Row(
                  children: [
                    Icon(Icons.payment, color: Colors.green),
                    SizedBox(width: 10),
                    Text('Confirm Payment',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Mock Payment — Selcom integration coming soon',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                // Room info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: p.imageUrls.isNotEmpty
                            ? Image.network(p.imageUrls.first,
                                width: 56, height: 56, fit: BoxFit.cover)
                            : Container(
                                width: 56, height: 56,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.apartment_rounded),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(p.locationLabel,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text('$_durationMonths month(s)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Duration / Dates
                _PayRow(label: 'Lease start', value: dateFmt.format(startDate)),
                _PayRow(label: 'Lease end', value: dateFmt.format(endDate)),
                const Divider(height: 24),
                // Cost breakdown — what is paid NOW to reserve
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text('Amount to pay online (28.5% of 1 mo rent)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 8),
                _PayRow(label: 'iRent fee (5%)', value: 'TSH ${fmt.format(fee.round())}'),
                _PayRow(label: 'Gateway fee (3.5%)', value: 'TSH ${fmt.format(gateway.round())}'),
                _PayRow(
                  label: p.dalaliId != null ? 'Service fee — Dalali (20%)' : 'Service fee (20%)',
                  value: 'TSH ${fmt.format(serviceFee.round())}',
                ),
                const Divider(height: 16),
                _PayRow(
                  label: 'Total to pay now',
                  value: 'TSH ${fmt.format(toPay.round())}',
                  bold: true,
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 6),
                Text(
                  'Remaining rent (TSH ${fmt.format(totalRent.round())}) paid in cash to landlord at move-in.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                // Pay button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.lock),
                    label: Text(
                      'Pay TSH ${fmt.format(toPay.round())} & Reserve',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _reserving
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await _doReserve(p, tenantId, startDate, endDate);
                          },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('Secure mock payment • Selcom coming soon',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _doReserve(Property p, String tenantId, DateTime start, DateTime end) async {
    setState(() => _reserving = true);

    try {
      final client = Supabase.instance.client;

      // 0 — Server-side guard: ensure tenant has no existing active booking
      final existing = await client
          .from('bookings')
          .select('id')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['reserved', 'occupied'])
          .limit(1);

      if ((existing as List).isNotEmpty) {
        if (mounted) {
          setState(() { _hasActiveBooking = true; _reserving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a reserved room. Release it first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 1 — Insert booking with lease dates
      await client.from('bookings').insert({
        'property_id': p.id,
        'tenant_id': tenantId,
        'landlord_id': p.ownerId,
        'duration_months': _durationMonths,
        'rent_amount': p.price,
        'reservation_fee': _platformFee(p.price) + _gatewayFee(p.price),
        'dalali_fee': _serviceFee(p.price),   // 20% service fee (goes to dalali or iRent if landlord)
        'status': 'reserved',
        'reserved_at': start.toIso8601String(),
        'lease_start': start.toIso8601String(),
        'lease_end': end.toIso8601String(),
      });

      // 2 — Mark property as reserved → hides from public listing
      await client
          .from('properties')
          .update({'status': 'reserved'})
          .eq('id', p.id);

      if (!mounted) return;
      setState(() => _hasActiveBooking = true);

      // 3 — Success dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Payment Successful!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You have reserved "${p.title}".', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Amount paid: TSH ${NumberFormat('#,###').format(_totalOnline(p.price).round())}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'The room is now under your name and visible in "My Room".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop();
              },
              child: const Text('View My Room'),
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
    final p = _property;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Detail')),
        body: Center(
          child: _fetchingProperty 
              ? const CircularProgressIndicator() 
              : const Text('Room not found or no longer available.'),
        ),
      );
    }

    final images = p.imageUrls;
    final lat = p.latitude ?? -6.7924;
    final lng = p.longitude ?? 39.2083;
    final isAlreadyReserved = p.status == 'reserved';
    final userAsync = ref.watch(appUserProvider);
    final user = userAsync.value;
    final isOwner = user != null && p.ownerId == user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/properties/add',
                  extra: p,
                ),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            )
          else ...[
            IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          ]
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
                      name: p.uploaderName ?? 'Unknown',
                      role: p.uploaderRole ?? 'Landlord',
                      phone: p.uploaderPhone,
                      isReserved: isAlreadyReserved,
                      isOwner: isOwner,
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
                                label: 'iRent fee (5% × 1 mo rent)',
                                value: 'TSH ${_fmt(_platformFee(p.price))}',
                              ),
                              const SizedBox(height: 6),
                              _CostRow(
                                label: 'Gateway fee (3.5% × 1 mo rent)',
                                value: 'TSH ${_fmt(_gatewayFee(p.price))}',
                              ),
                              const SizedBox(height: 6),
                              _CostRow(
                                label: p.dalaliId != null
                                    ? 'Service fee — Dalali (20%)'
                                    : 'Service fee (20% × 1 mo rent)',
                                value: 'TSH ${_fmt(_serviceFee(p.price))}',
                              ),
                              const Divider(height: 20),
                              _CostRow(
                                label: 'Total to Pay Online (28.5%)',
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
        child: isOwner
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('You own this property',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              )
                   : isAlreadyReserved
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
                : _hasActiveBooking
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'You already have a reserved room',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A tenant can only reserve one room at a time. Go to My Room to view it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                        ),
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
    this.phone,
    required this.isReserved,
    required this.isOwner,
  });

  final String name;
  final String role;
  final String? phone;
  final bool isReserved;
  final bool isOwner;

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
          if (isOwner || isReserved) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: cs.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwner ? 'Your Contact Details' : 'Landlord Contact',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone ?? 'No phone number provided',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
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
                  const Expanded(
                    child: Text(
                      'Contact info hidden. Reserve to unlock phone & chat.',
                      style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

// _PayRow \u2014 used in the mock payment sheet (same layout as _CostRow)
class _PayRow extends StatelessWidget {
  const _PayRow({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: textColor.withValues(alpha: bold ? 1.0 : 0.7),
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: textColor)),
        ],
      ),
    );
  }
}
