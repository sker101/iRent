class Property {
  const Property({
    required this.id,
    required this.title,
    required this.price,
    required this.roomType,
    this.description,
    this.district,
    this.ward,
    this.region,
    this.bedrooms = 1,
    this.bathrooms = 1,
    this.furnished = false,
    this.status = 'live',
    this.coverImageUrl,
    this.imageUrls = const [],
    this.latitude,
    this.longitude,
    this.genderPreference,
    this.houseRules,
    this.availableFrom,
    // utilities
    this.electricityCost = 0,
    this.electricityNote = 'independent',
    this.waterCost = 0,
    this.waterNote = 'independent',
    this.wasteCost = 0,
    this.wasteNote = 'not charged',
    this.securityCost = 0,
    this.securityNote = 'not charged',
    // amenities
    this.amenities = const [],
    // uploader info
    this.ownerId,
    this.dalaliId,
    this.uploaderName,
    this.uploaderRole,
  });

  final String id;
  final String title;
  final String? description;
  final double price;
  final String? district;
  final String? ward;
  final String? region;
  final String roomType;
  final int bedrooms;
  final int bathrooms;
  final bool furnished;
  final String status;
  final String? coverImageUrl;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final String? genderPreference;
  final String? houseRules;
  final DateTime? availableFrom;

  // utilities
  final double electricityCost;
  final String electricityNote;
  final double waterCost;
  final String waterNote;
  final double wasteCost;
  final String wasteNote;
  final double securityCost;
  final String securityNote;

  // amenities
  final List<String> amenities;

  // uploader info
  final String? ownerId;
  final String? dalaliId;
  final String? uploaderName;
  final String? uploaderRole;

  /// Total monthly utility charges
  double get totalMonthlyUtilities =>
      electricityCost + waterCost + wasteCost + securityCost;

  String get locationLabel {
    if (ward != null && district != null) return '$ward, $district';
    return district ?? ward ?? region ?? 'Unknown';
  }

  String get roomTypeLabel {
    switch (roomType) {
      case 'self_contained':
        return 'Self-contained';
      case 'bedsitter':
        return 'Bedsitter';
      case 'single':
        return 'Single room';
      case 'double':
        return 'Double room';
      case 'house':
        return 'House';
      default:
        return roomType;
    }
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final rawImages = json['property_images'];
    final images = rawImages is List
        ? rawImages
            .map((img) => img['url'] as String? ?? '')
            .where((url) => url.isNotEmpty)
            .toList()
        : <String>[];

    // Parse amenities — stored as a postgres array (List<dynamic>)
    final rawAmenities = json['amenities'];
    final amenityList = rawAmenities is List
        ? rawAmenities.map((a) => a.toString()).toList()
        : <String>[];

    // Attempt to parse uploader from joined users table
    String? uploaderName;
    String? uploaderRole;
    
    // Supabase join typically returns a nested object if we query users!owner_id(...)
    // Let's check for an 'owner' or 'dalali' key, or parse from 'users' if returned that way.
    // We'll standardize on alias 'uploader' in the query: `uploader:users!owner_id(full_name, role)`
    final rawUploader = json['uploader'];
    if (rawUploader is Map) {
      uploaderName = rawUploader['full_name'] as String?;
      uploaderRole = rawUploader['role'] as String?;
    } else {
      // fallback in case query returns 'users' object
      final rawUsers = json['users'];
      if (rawUsers is Map) {
        uploaderName = rawUsers['full_name'] as String?;
        uploaderRole = rawUsers['role'] as String?;
      }
    }

    return Property(
      id: json['id'] as String,
      title: json['title'] as String,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      roomType: json['room_type'] as String? ?? 'single',
      description: json['description'] as String?,
      district: json['district'] as String?,
      ward: json['ward'] as String?,
      region: json['region'] as String?,
      bedrooms: json['bedrooms'] as int? ?? 1,
      bathrooms: json['bathrooms'] as int? ?? 1,
      furnished: json['furnished'] as bool? ?? false,
      status: json['status'] as String? ?? 'live',
      coverImageUrl: images.isNotEmpty ? images.first : null,
      imageUrls: images,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      genderPreference: json['gender_preference'] as String?,
      houseRules: json['house_rules'] as String?,
      availableFrom: json['available_from'] != null
          ? DateTime.tryParse(json['available_from'] as String)
          : null,
      electricityCost: double.tryParse(json['electricity_cost'].toString()) ?? 0,
      electricityNote: json['electricity_note'] as String? ?? 'independent',
      waterCost: double.tryParse(json['water_cost'].toString()) ?? 0,
      waterNote: json['water_note'] as String? ?? 'independent',
      wasteCost: double.tryParse(json['waste_cost'].toString()) ?? 0,
      wasteNote: json['waste_note'] as String? ?? 'not charged',
      securityCost: double.tryParse(json['security_cost'].toString()) ?? 0,
      securityNote: json['security_note'] as String? ?? 'not charged',
      amenities: amenityList,
      ownerId: json['owner_id'] as String?,
      dalaliId: json['dalali_id'] as String?,
      uploaderName: uploaderName,
      uploaderRole: uploaderRole,
    );
  }
}
