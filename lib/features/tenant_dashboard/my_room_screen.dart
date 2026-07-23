import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';

// Data model for the tenant's booked room
class _BookedRoom {
  final String propertyId;
  final String bookingId;
  final String title;
  final String? location;
  final double rent;
  final String status;
  final String? imageUrl;
  final String? landlordName;
  final String? landlordId;
  final String? landlordRole;
  final DateTime? leaseStart;
  final DateTime? leaseEnd;
  final int durationMonths;
  final String? houseRules;
  final String? tenantContractUrl;
  final String? landlordContractUrl;

  const _BookedRoom({
    required this.propertyId,
    required this.bookingId,
    required this.title,
    this.location,
    required this.rent,
    required this.status,
    this.imageUrl,
    this.landlordName,
    this.landlordId,
    this.landlordRole,
    this.leaseStart,
    this.leaseEnd,
    required this.durationMonths,
    this.houseRules,
    this.tenantContractUrl,
    this.landlordContractUrl,
  });
}

class MyRoomScreen extends ConsumerStatefulWidget {
  const MyRoomScreen({super.key});

  @override
  ConsumerState<MyRoomScreen> createState() => _MyRoomScreenState();
}

class _MyRoomScreenState extends ConsumerState<MyRoomScreen> {
  late Future<List<_BookedRoom>> _future;

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
      _future = _loadRooms(user.id);
    });
  }

  Future<List<_BookedRoom>> _loadRooms(String userId) async {
    try {
      final res = await Supabase.instance.client
          .from('bookings')
          .select(
            'id, status, duration_months, rent_amount, lease_start, lease_end, reserved_at, tenant_contract_url, landlord_contract_url, '
            'properties(id, title, ward, district, price, house_rules, property_images(url, sort_order)), '
            'landlord:users!landlord_id(id, full_name, role)',
          )
          .eq('tenant_id', userId)
          // Only show active (reserved or occupied) bookings — never show completed/cancelled
          .inFilter('status', ['reserved', 'occupied'])
          // One room per tenant — DB partial index also enforces this
          .order('reserved_at', ascending: false)
          .limit(1);

      final List<_BookedRoom> rooms = [];

      for (final b in (res as List)) {
        final prop = b['properties'] as Map? ?? {};
        final propertyId = prop['id'] as String? ?? '';

        final landlord = b['landlord'] as Map? ?? {};
        final imgs = prop['property_images'] as List? ?? [];
        imgs.sort((a, b) => ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int));
        final imageUrl = imgs.isNotEmpty ? imgs.first['url'] as String? : null;

        final ward = prop['ward'] as String?;
        final district = prop['district'] as String?;
        final location = [ward, district].whereType<String>().join(', ');

        DateTime? leaseStart;
        DateTime? leaseEnd;
        if (b['lease_start'] != null) leaseStart = DateTime.tryParse(b['lease_start'] as String);
        if (b['lease_end'] != null) leaseEnd = DateTime.tryParse(b['lease_end'] as String);
        // Fallback to reserved_at if lease fields aren't set
        if (leaseStart == null && b['reserved_at'] != null) {
          leaseStart = DateTime.tryParse(b['reserved_at'] as String);
          final dur = (b['duration_months'] as num?)?.toInt() ?? 1;
          if (leaseStart != null) {
            leaseEnd = DateTime(leaseStart.year, leaseStart.month + dur, leaseStart.day);
          }
        }

        rooms.add(_BookedRoom(
          propertyId: propertyId,
          bookingId: b['id'] as String? ?? '',
          title: prop['title'] as String? ?? 'Property',
          location: location.isEmpty ? null : location,
          rent: (b['rent_amount'] as num?)?.toDouble() ?? (prop['price'] as num?)?.toDouble() ?? 0,
          status: b['status'] as String? ?? 'reserved',
          imageUrl: imageUrl,
          landlordName: landlord['full_name'] as String?,
          landlordId: landlord['id'] as String?,
          landlordRole: landlord['role'] as String?,
          leaseStart: leaseStart,
          leaseEnd: leaseEnd,
          durationMonths: (b['duration_months'] as num?)?.toInt() ?? 1,
          houseRules: prop['house_rules'] as String?,
          tenantContractUrl: b['tenant_contract_url'] as String?,
          landlordContractUrl: b['landlord_contract_url'] as String?,
        ));
      }
      return rooms;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('My Room', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
      ),
      body: FutureBuilder<List<_BookedRoom>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key, size: 72, color: cs.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('No rooms yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Rooms you reserve and pay for will appear here.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.search),
                    label: const Text('Explore Rooms'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _fetch(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _MyRoomCard(
                room: list[i],
                onChat: (landlordId) => _openChat(landlordId),
                onViewRoom: (propertyId) =>
                    context.push('/rooms/$propertyId'),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChat(String? landlordId) {
    if (landlordId == null) return;
    context.push('/messages/$landlordId');
  }
}

class _MyRoomCard extends StatefulWidget {
  const _MyRoomCard({
    required this.room,
    required this.onChat,
    required this.onViewRoom,
  });
  final _BookedRoom room;
  final void Function(String?) onChat;
  final void Function(String) onViewRoom;

  @override
  State<_MyRoomCard> createState() => _MyRoomCardState();
}

class _MyRoomCardState extends State<_MyRoomCard> {
  int _tabIndex = 0;
  bool _isUploadingContract = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isReserved = widget.room.status == 'reserved';
    final isOccupied = widget.room.status == 'occupied';
    final fmt = DateFormat('dd MMM yyyy');
    final moneyFmt = NumberFormat('#,###');

    // Countdown / time remaining
    String countdownText = '';
    double progress = 0;
    Color countdownColor = cs.primary;
    if (widget.room.leaseStart != null && widget.room.leaseEnd != null) {
      final total = widget.room.leaseEnd!.difference(widget.room.leaseStart!).inDays;
      final elapsed = now.difference(widget.room.leaseStart!).inDays.clamp(0, total);
      final remaining = widget.room.leaseEnd!.difference(now);
      progress = total > 0 ? elapsed / total : 0;
      if (remaining.isNegative) {
        countdownText = 'Lease ended';
        countdownColor = Colors.red;
      } else if (remaining.inDays == 0) {
        countdownText = 'Ends today!';
        countdownColor = Colors.red;
      } else if (remaining.inDays == 1) {
        countdownText = '1 day remaining';
        countdownColor = Colors.orange;
      } else if (remaining.inDays <= 7) {
        countdownText = '${remaining.inDays} days remaining';
        countdownColor = Colors.orange;
      } else if (remaining.inDays < 30) {
        countdownText = '${remaining.inDays} days remaining';
      } else {
        final months = (remaining.inDays / 30).floor();
        final days = remaining.inDays % 30;
        countdownText = days > 0
            ? '$months months, $days days remaining'
            : '$months months remaining';
      }
    }

    final statusColor = isOccupied
        ? Colors.green
        : isReserved
            ? Colors.orange
            : Colors.grey;

    final roleLabel = (widget.room.landlordRole ?? '').toLowerCase() == 'dalali'
        ? 'Dalali'
        : 'Landlord';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          GestureDetector(
            onTap: () => widget.onViewRoom(widget.room.propertyId),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: widget.room.imageUrl != null
                  ? Image.network(widget.room.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: cs.surfaceContainerHigh,
                      child: Icon(Icons.apartment_rounded,
                          size: 56, color: cs.outlineVariant),
                    ),
            ),
          ),
          
          // Tabs
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: _tabIndex == 0 ? cs.primary : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    alignment: Alignment.center,
                    child: Text('Room Details', style: TextStyle(
                      fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                      color: _tabIndex == 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                    )),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: _tabIndex == 1 ? cs.primary : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    alignment: Alignment.center,
                    child: Text('Contract', style: TextStyle(
                      fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _tabIndex == 1 ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                    )),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: _tabIndex == 0
              ? GestureDetector(
                  onTap: () => widget.onViewRoom(widget.room.propertyId),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Title + Status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(widget.room.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.room.status[0].toUpperCase() +
                                widget.room.status.substring(1),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    if (widget.room.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(widget.room.location!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Rent price
                    Text(
                      'TSH ${moneyFmt.format(widget.room.rent.round())} / month',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary),
                    ),

                    // Lease dates
                    if (widget.room.leaseStart != null && widget.room.leaseEnd != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _DateChip(
                                  label: 'Lease Start',
                                  date: fmt.format(widget.room.leaseStart!),
                                  icon: Icons.flight_land,
                                  color: Colors.green.shade600,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: cs.onSurface.withValues(alpha: 0.6)),
                                ),
                                _DateChip(
                                  label: 'Lease End',
                                  date: fmt.format(widget.room.leaseEnd!),
                                  icon: Icons.flight_takeoff,
                                  color: Colors.red.shade500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor:
                                    cs.outlineVariant.withValues(alpha: 0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    countdownColor),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${widget.room.durationMonths} month(s) total',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.5)),
                                ),
                                Text(
                                  countdownText,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: countdownColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Landlord info + actions
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Landlord avatar
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.15),
                          child: Text(
                            widget.room.landlordName != null &&
                                    widget.room.landlordName!.isNotEmpty
                                ? widget.room.landlordName!
                                    .trim()
                                    .split(' ')
                                    .map((e) => e[0])
                                    .take(2)
                                    .join()
                                    .toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.room.landlordName ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.55)),
                              ),
                            ],
                          ),
                        ),
                        // Chat button
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: widget.room.landlordId != null
                                ? () => widget.onChat(widget.room.landlordId)
                                : null,
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('Chat'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Share button (Placeholder)
                        IconButton.filledTonal(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sharing coming soon!')),
                            );
                          },
                          icon: const Icon(Icons.share, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('House Rules & Contract',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.room.houseRules?.isNotEmpty == true
                            ? widget.room.houseRules!
                            : 'No specific house rules provided by the landlord.',
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tenant Signature',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (widget.room.tenantContractUrl != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.green.withValues(alpha: 0.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Signed contract uploaded successfully.')),
                            TextButton(
                              onPressed: () => _uploadContract(context),
                              child: const Text('Re-upload'),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Please download the contract, sign it, and upload a photo of the signed contract below.',
                            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 12),
                          if (_isUploadingContract)
                            const Center(child: CircularProgressIndicator())
                          else
                            OutlinedButton.icon(
                              onPressed: () => _uploadContract(context),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload Signed Contract'),
                            ),
                        ],
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadContract(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    if (!mounted) return;
    setState(() => _isUploadingContract = true);

    try {
      final ext = file.path.split('.').last;
      final path = '${widget.room.bookingId}/tenant_contract_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      final storage = Supabase.instance.client.storage.from('contracts');
      await storage.upload(path, File(file.path));
      final publicUrl = storage.getPublicUrl(path);

      await Supabase.instance.client
          .from('bookings')
          .update({'tenant_contract_url': publicUrl})
          .eq('id', widget.room.bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract uploaded successfully')),
        );
        // Refresh would be ideal here, but since this is a child widget, 
        // the user can pull-to-refresh to see it, or we could pass a callback.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.icon,
    required this.color,
  });
  final String label;
  final String date;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(date,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
