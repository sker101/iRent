import 'package:flutter_test/flutter_test.dart';
import 'package:irent/models/property_listing.dart';

void main() {
  group('PropertyListing', () {
    test('parses a Supabase-style payload', () {
      final listing = PropertyListing.fromJson({
        'id': 'abc123',
        'title': 'Sample room',
        'description': 'Bright room in Dar es Salaam',
        'price': 180000,
        'district': 'Ilala',
        'room_type': 'single',
      });

      expect(listing.id, 'abc123');
      expect(listing.title, 'Sample room');
      expect(listing.price, 180000);
      expect(listing.location, 'Ilala');
    });
  });
}
