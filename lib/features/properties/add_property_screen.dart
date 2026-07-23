import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';

// ── Amenity catalogue ──────────────────────────────────────────────────────

class _Amenity {
  const _Amenity(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _allAmenities = [
  _Amenity('wifi', 'WiFi', Icons.wifi),
  _Amenity('electricity', 'Electricity', Icons.bolt),
  _Amenity('water', 'Water', Icons.water_drop),
  _Amenity('parking', 'Parking', Icons.local_parking),
  _Amenity('security_guard', 'Security Guard', Icons.security),
  _Amenity('cctv', 'CCTV', Icons.videocam),
  _Amenity('air_conditioning', 'Air Conditioning', Icons.ac_unit),
  _Amenity('fan', 'Fan', Icons.air),
  _Amenity('private_bathroom', 'Private Bathroom', Icons.shower),
  _Amenity('shared_bathroom', 'Shared Bathroom', Icons.bathtub),
  _Amenity('kitchen', 'Kitchen', Icons.kitchen),
  _Amenity('furnished', 'Furnished', Icons.chair),
  _Amenity('balcony', 'Balcony', Icons.deck),
  _Amenity('garden', 'Garden', Icons.park),
  _Amenity('generator', 'Generator', Icons.electrical_services),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key, this.propertyToEdit});
  final Property? propertyToEdit;

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  // basic
  String _title = '';
  String _description = '';
  String _houseRules = '';
  double _price = 0;
  String _region = '';
  String _district = '';
  String _ward = '';
  double _latitude = -6.7924;
  double _longitude = 39.2083;
  String _roomType = 'single';
  int _bedrooms = 1;
  int _bathrooms = 1;
  bool _furnished = false;

  // utilities
  final _elecCostCtrl  = TextEditingController(text: '0');
  final _waterCostCtrl = TextEditingController(text: '0');
  final _wasteCostCtrl = TextEditingController(text: '0');
  final _secCostCtrl   = TextEditingController(text: '0');

  String _elecNote  = 'independent';
  String _waterNote = 'independent';
  String _wasteNote = 'not charged';
  String _secNote   = 'not charged';

  // amenities
  final Set<String> _selectedAmenities = {};

  // photos
  final List<File> _images = [];
  bool _isSubmitting = false;

  // auto-save
  Timer? _debounceTimer;
  bool _isLoadingDraft = false;
  bool _hasDraft = false;

  bool get _isEditing => widget.propertyToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.propertyToEdit!;
      _title = p.title;
      _description = p.description ?? '';
      _houseRules = p.houseRules ?? '';
      _price = p.price;
      _region = p.region ?? '';
      _district = p.district ?? '';
      _ward = p.ward ?? '';
      _latitude = p.latitude ?? -6.7924;
      _longitude = p.longitude ?? 39.2083;
      _roomType = p.roomType;
      _bedrooms = p.bedrooms;
      _bathrooms = p.bathrooms;
      _furnished = p.furnished;
      
      _elecCostCtrl.text = p.electricityCost.toStringAsFixed(0);
      _waterCostCtrl.text = p.waterCost.toStringAsFixed(0);
      _wasteCostCtrl.text = p.wasteCost.toStringAsFixed(0);
      _secCostCtrl.text = p.securityCost.toStringAsFixed(0);
      
      _elecNote = p.electricityNote;
      _waterNote = p.waterNote;
      _wasteNote = p.wasteNote;
      _secNote = p.securityNote;
      
      _selectedAmenities.addAll(p.amenities);
    } else {
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    setState(() => _isLoadingDraft = true);
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString('draft_property');
    if (draftStr != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(draftStr);
        _title = data['title'] ?? '';
        _description = data['description'] ?? '';
        _houseRules = data['houseRules'] ?? '';
        _price = (data['price'] ?? 0).toDouble();
        _region = data['region'] ?? '';
        _district = data['district'] ?? '';
        _ward = data['ward'] ?? '';
        _latitude = (data['latitude'] ?? -6.7924).toDouble();
        _longitude = (data['longitude'] ?? 39.2083).toDouble();
        _roomType = data['roomType'] ?? 'single';
        _bedrooms = data['bedrooms'] ?? 1;
        _bathrooms = data['bathrooms'] ?? 1;
        _furnished = data['furnished'] ?? false;
        
        _elecCostCtrl.text = data['elecCost'] ?? '0';
        _waterCostCtrl.text = data['waterCost'] ?? '0';
        _wasteCostCtrl.text = data['wasteCost'] ?? '0';
        _secCostCtrl.text = data['secCost'] ?? '0';
        
        _elecNote = data['elecNote'] ?? 'independent';
        _waterNote = data['waterNote'] ?? 'independent';
        _wasteNote = data['wasteNote'] ?? 'not charged';
        _secNote = data['secNote'] ?? 'not charged';

        if (data['amenities'] != null) {
          _selectedAmenities.addAll(List<String>.from(data['amenities']));
        }
        _hasDraft = true;
      } catch (e) {
        debugPrint('Failed to load draft: $e');
      }
    }
    if (mounted) setState(() => _isLoadingDraft = false);
  }

  void _triggerSaveDraft() {
    if (_isEditing) return; // Don't auto-save if we are editing an existing property
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditing) return;
    
    // Save controller values immediately instead of waiting for form save
    final data = {
      'title': _title,
      'description': _description,
      'houseRules': _houseRules,
      'price': _price,
      'region': _region,
      'district': _district,
      'ward': _ward,
      'latitude': _latitude,
      'longitude': _longitude,
      'roomType': _roomType,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'furnished': _furnished,
      
      'elecCost': _elecCostCtrl.text,
      'waterCost': _waterCostCtrl.text,
      'wasteCost': _wasteCostCtrl.text,
      'secCost': _secCostCtrl.text,
      
      'elecNote': _elecNote,
      'waterNote': _waterNote,
      'wasteNote': _wasteNote,
      'secNote': _secNote,
      
      'amenities': _selectedAmenities.toList(),
    };
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_property', jsonEncode(data));
    if (mounted && !_hasDraft) {
      setState(() => _hasDraft = true);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_property');
    
    setState(() {
      _hasDraft = false;
      _title = '';
      _description = '';
      _houseRules = '';
      _price = 0;
      _region = '';
      _district = '';
      _ward = '';
      _latitude = -6.7924;
      _longitude = 39.2083;
      _roomType = 'single';
      _bedrooms = 1;
      _bathrooms = 1;
      _furnished = false;
      
      _elecCostCtrl.text = '0';
      _waterCostCtrl.text = '0';
      _wasteCostCtrl.text = '0';
      _secCostCtrl.text = '0';
      
      _elecNote = 'independent';
      _waterNote = 'independent';
      _wasteNote = 'not charged';
      _secNote = 'not charged';
      
      _selectedAmenities.clear();
      _images.clear();
    });
    
    // reset form validation state
    _formKey.currentState?.reset();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _elecCostCtrl.dispose();
    _waterCostCtrl.dispose();
    _wasteCostCtrl.dispose();
    _secCostCtrl.dispose();
    super.dispose();
  }

  // ── Photo picker ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo')),
      );
      return;
    }
    _formKey.currentState!.save();

    final user = ref.read(appUserProvider).value;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final dalaliId = user.role == UserRole.dalali ? user.id : null;
      final ownerId = user.id;

      final updates = {
        'owner_id': ownerId,
        'dalali_id': ?dalaliId,
        'title': _title,
        'description': _description,
        'price': _price,
        'region': _region,
        'district': _district,
        'ward': _ward,
        'latitude': _latitude,
        'longitude': _longitude,
        'room_type': _roomType,
        'bedrooms': _bedrooms,
        'bathrooms': _bathrooms,
        'furnished': _furnished,
        'house_rules': _houseRules,
        'status': 'live',
        // utilities
        'electricity_cost': double.tryParse(_elecCostCtrl.text) ?? 0,
        'electricity_note': _elecNote,
        'water_cost': double.tryParse(_waterCostCtrl.text) ?? 0,
        'water_note': _waterNote,
        'waste_cost': double.tryParse(_wasteCostCtrl.text) ?? 0,
        'waste_note': _wasteNote,
        'security_cost': double.tryParse(_secCostCtrl.text) ?? 0,
        'security_note': _secNote,
        // amenities
        'amenities': _selectedAmenities.toList(),
      };

      String propertyId;
      if (_isEditing) {
        propertyId = widget.propertyToEdit!.id;
        await Supabase.instance.client
            .from('properties')
            .update(updates)
            .eq('id', propertyId);
      } else {
        final res = await Supabase.instance.client
            .from('properties')
            .insert(updates)
            .select('id')
            .single();
        propertyId = res['id'] as String;
      }

      // 2 — Upload images
      final storage = Supabase.instance.client.storage.from('properties');
      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final ext = file.path.split('.').last;
        final path = '$propertyId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await storage.upload(path, file);
        final publicUrl = storage.getPublicUrl(path);
        await Supabase.instance.client.from('property_images').insert({
          'property_id': propertyId,
          'url': publicUrl,
          'sort_order': i,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            _isEditing ? 'Property updated successfully!' : 'Property uploaded successfully!'
          )),
        );
        if (!_isEditing) {
          await _clearDraft();
        }
        if (mounted) context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add Property'),
        actions: [
          if (!_isEditing && _hasDraft)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear Draft',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Clear Draft?'),
                    content: const Text('Are you sure you want to discard your saved draft and start over?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _clearDraft();
                }
              },
            ),
        ],
      ),
      body: _isLoadingDraft || _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Photos ─────────────────────────────────────────────
                  _SectionHeader(title: 'Photos'),
                  const SizedBox(height: 12),
                  if (_images.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) => Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(_images[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 16,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Add Photos'),
                  ),
                  const SizedBox(height: 28),

                  // ── Basic Details ──────────────────────────────────────
                  _SectionHeader(title: 'Basic Details'),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _title,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    onChanged: (v) { _title = v; _triggerSaveDraft(); },
                    onSaved: (v) => _title = v!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _description,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 3,
                    onChanged: (v) { _description = v; _triggerSaveDraft(); },
                    onSaved: (v) => _description = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _houseRules,
                    decoration: const InputDecoration(
                      labelText: 'House Rules',
                      hintText: 'Rules for the tenant, to be included in the contract.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (v) => v == null || v.isEmpty ? 'House rules are required for the contract' : null,
                    onChanged: (v) { _houseRules = v; _triggerSaveDraft(); },
                    onSaved: (v) => _houseRules = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _price == 0 ? '' : _price.toStringAsFixed(0),
                    decoration: const InputDecoration(
                        labelText: 'Monthly Rent (TZS)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                    onChanged: (v) { _price = double.tryParse(v) ?? _price; _triggerSaveDraft(); },
                    onSaved: (v) => _price = double.parse(v!),
                  ),
                  const SizedBox(height: 28),

                  // ── Location ───────────────────────────────────────────
                  _SectionHeader(title: 'Location'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _region,
                          decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
                          onChanged: (v) { _region = v; _triggerSaveDraft(); },
                          onSaved: (v) => _region = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _district,
                          decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                          onChanged: (v) { _district = v; _triggerSaveDraft(); },
                          onSaved: (v) => _district = v ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _ward,
                    decoration: const InputDecoration(labelText: 'Ward', border: OutlineInputBorder()),
                    onChanged: (v) { _ward = v; _triggerSaveDraft(); },
                    onSaved: (v) => _ward = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _latitude.toString(),
                          decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (v) { _latitude = double.tryParse(v) ?? _latitude; _triggerSaveDraft(); },
                          onSaved: (v) => _latitude = double.tryParse(v ?? '') ?? _latitude,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _longitude.toString(),
                          decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (v) { _longitude = double.tryParse(v) ?? _longitude; _triggerSaveDraft(); },
                          onSaved: (v) => _longitude = double.tryParse(v ?? '') ?? _longitude,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Room Features ──────────────────────────────────────
                  _SectionHeader(title: 'Room Features'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _roomType,
                    decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'single', child: Text('Single')),
                      DropdownMenuItem(value: 'double', child: Text('Double')),
                      DropdownMenuItem(value: 'bedsitter', child: Text('Bedsitter')),
                      DropdownMenuItem(value: 'self_contained', child: Text('Self-contained')),
                      DropdownMenuItem(value: 'house', child: Text('House')),
                    ],
                    onChanged: (v) {
                      setState(() { _roomType = v!; });
                      _triggerSaveDraft();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _bedrooms.toString(),
                          decoration: const InputDecoration(labelText: 'Bedrooms', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) { _bedrooms = int.tryParse(v) ?? _bedrooms; _triggerSaveDraft(); },
                          onSaved: (v) => _bedrooms = int.tryParse(v ?? '1') ?? 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _bathrooms.toString(),
                          decoration: const InputDecoration(labelText: 'Bathrooms', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) { _bathrooms = int.tryParse(v) ?? _bathrooms; _triggerSaveDraft(); },
                          onSaved: (v) => _bathrooms = int.tryParse(v ?? '1') ?? 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Furnished'),
                    value: _furnished,
                    onChanged: (v) {
                      setState(() { _furnished = v; });
                      _triggerSaveDraft();
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 28),

                  // ── Monthly Utilities ──────────────────────────────────
                  _SectionHeader(
                    title: 'Monthly Utility Costs',
                    subtitle: 'Enter 0 if no charge. This helps tenants know what to expect.',
                  ),
                  const SizedBox(height: 12),
                  _UtilityRow(
                    icon: Icons.bolt,
                    iconColor: Colors.orange,
                    label: 'Electricity (LUKU)',
                    costController: _elecCostCtrl,
                    note: _elecNote,
                    noteOptions: const ['independent', 'shared', 'included in rent', 'no charge'],
                    onNoteChanged: (v) { setState(() { _elecNote = v; }); _triggerSaveDraft(); },
                    onCostChanged: (v) { _triggerSaveDraft(); },
                  ),
                  const SizedBox(height: 12),
                  _UtilityRow(
                    icon: Icons.water_drop,
                    iconColor: Colors.blue,
                    label: 'Water (DAWASA)',
                    costController: _waterCostCtrl,
                    note: _waterNote,
                    noteOptions: const ['independent', 'shared', 'included in rent', 'no charge'],
                    onNoteChanged: (v) { setState(() { _waterNote = v; }); _triggerSaveDraft(); },
                    onCostChanged: (v) { _triggerSaveDraft(); },
                  ),
                  const SizedBox(height: 12),
                  _UtilityRow(
                    icon: Icons.delete_outline,
                    iconColor: Colors.grey,
                    label: 'Waste Collection',
                    costController: _wasteCostCtrl,
                    note: _wasteNote,
                    noteOptions: const ['not charged', 'shared', 'included in rent', 'fixed charge'],
                    onNoteChanged: (v) { setState(() { _wasteNote = v; }); _triggerSaveDraft(); },
                    onCostChanged: (v) { _triggerSaveDraft(); },
                  ),
                  const SizedBox(height: 12),
                  _UtilityRow(
                    icon: Icons.security,
                    iconColor: Colors.indigo,
                    label: 'Security',
                    costController: _secCostCtrl,
                    note: _secNote,
                    noteOptions: const ['not charged', 'shared', 'included in rent', 'fixed charge'],
                    onNoteChanged: (v) { setState(() { _secNote = v; }); _triggerSaveDraft(); },
                    onCostChanged: (v) { _triggerSaveDraft(); },
                  ),
                  const SizedBox(height: 28),

                  // ── Amenities ──────────────────────────────────────────
                  _SectionHeader(
                    title: 'Amenities',
                    subtitle: 'Tap to select what is available in this room.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _allAmenities.map((a) {
                      final selected = _selectedAmenities.contains(a.id);
                      return FilterChip(
                        avatar: Icon(
                          a.icon,
                          size: 16,
                          color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.6),
                        ),
                        label: Text(a.label),
                        selected: selected,
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(
                          color: selected ? cs.onPrimary : cs.onSurface,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedAmenities.add(a.id);
                            } else {
                              _selectedAmenities.remove(a.id);
                            }
                          });
                          _triggerSaveDraft();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 36),

                  // ── Submit ─────────────────────────────────────────────
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(_isEditing ? 'Save Changes' : 'Upload Property', style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
        ],
      ],
    );
  }
}

class _UtilityRow extends StatelessWidget {
  const _UtilityRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.costController,
    required this.note,
    required this.noteOptions,
    required this.onNoteChanged,
    required this.onCostChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController costController;
  final String note;
  final List<String> noteOptions;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<String> onCostChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: costController,
                  decoration: const InputDecoration(
                    labelText: 'TZS / month',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixText: 'TSH ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: onCostChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: note,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: noteOptions
                      .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onNoteChanged(v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
