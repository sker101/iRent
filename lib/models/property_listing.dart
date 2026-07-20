class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.roomType,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String roomType;

  factory PropertyListing.fromJson(Map<String, dynamic> json) {
    return PropertyListing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled listing',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      location: json['district']?.toString() ?? 'Unknown location',
      roomType: json['room_type']?.toString() ?? 'single',
    );
  }
}
