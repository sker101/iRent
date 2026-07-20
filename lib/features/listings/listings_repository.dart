import 'listing_model.dart';

class ListingsRepository {
  Future<List<ListingModel>> fetchFeaturedListings() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return [
      ListingModel(
        id: '1',
        title: 'Cozy Apartment',
        subtitle: 'Bright and comfortable stay in Nairobi',
        price: 'KSh 2,500 / month',
        location: 'Nairobi, Kenya',
      ),
      ListingModel(
        id: '2',
        title: 'Modern Villa',
        subtitle: 'Spacious villa with a garden view',
        price: 'KSh 2,800 / month',
        location: 'Kisumu, Kenya',
      ),
    ];
  }
}
