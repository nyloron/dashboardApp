import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/elements/search/place_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

// Primary Dio client pointing to Photon
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://photon.komoot.io',
      headers: {'User-Agent': 'OsmFlutterApp/1.0 (nilsrauschmayr@gmail.com)'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});

/// Search query Notifier
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Autocomplete suggestions with automatic Nominatim fallback
final searchSuggProvider = FutureProvider.autoDispose<List<PlaceModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.trim().length < 3) return [];

  final dio = ref.watch(dioProvider);

  // --- STEP 1: Try Photon API First ---
  try {
    debugPrint("Searching Photon for query: '$query'");

    final response = await dio.get(
      '/api/',
      queryParameters: {
        'q': query.trim(),
        'limit': 5,
      },
    );

    final Map<String, dynamic> data = response.data is String
        ? jsonDecode(response.data)
        : response.data as Map<String, dynamic>;

    final features = data['features'] as List? ?? [];

    if (features.isNotEmpty) {
      return features.map((feature) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List;

        // Safely construct name without null concatenation crashes
        final street = properties['street'];
        final housenumber = properties['housenumber'];
        final baseName = properties['name'];

        final name = baseName ?? 
            ((street != null && housenumber != null) ? '$street, $housenumber' : street) ?? 
            properties['city'] ?? 
            'Unknown Location';

        final city = properties['city'] ?? properties['state'] ?? '';
        final country = properties['country'] ?? '';
        
        final shortName = name.toString();
        final displayName = [shortName, city, country]
            .where((s) => s != null && s.toString().isNotEmpty && !shortName.contains(s.toString()))
            .join(', ');

        return PlaceModel(
          shortName: shortName,
          displayName: displayName,
          latLng: LatLng(
            (coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble(),
          ),
          type: properties['osm_value'] ?? properties['osm_type'] ?? 'place',
        );
      }).toList();
    }
  } catch (e) {
    debugPrint("Photon search failed, attempting Nominatim fallback... Error: $e");
  }

  // --- STEP 2: Fallback to Nominatim if Photon fails ---
  try {
    debugPrint("Falling back to Nominatim for query: '$query'");

    final fallbackDio = Dio(
      BaseOptions(
        baseUrl: "https://nominatim.openstreetmap.org",
        headers: {'User-Agent': 'OsmFlutterApp/1.0 (nilsrauschmayr@gmail.com)'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    final response = await fallbackDio.get(
      '/search',
      queryParameters: {
        'q': query.trim(),
        'format': 'json',
        'limit': 5,
        'addressdetails': 1,
      },
    );

    final List data = response.data is String
        ? jsonDecode(response.data)
        : response.data as List;

    return data
        .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
        .toList();

  } catch (fallbackError) {
    debugPrint("Nominatim fallback also failed: $fallbackError");
    return [];
  }
});

final selectedPlaceProvider = StateProvider<PlaceModel?>((ref) => null);