import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/property_listing.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PropertyListing>> fetchLiveListings() async {
    try {
      final response = await _client
          .from('properties')
          .select()
          .eq('status', 'live')
          .limit(10);

      final rows = response as List<dynamic>;
      return rows
          .map(
            (json) => PropertyListing.fromJson(
              Map<String, dynamic>.from(json as Map<String, dynamic>),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
