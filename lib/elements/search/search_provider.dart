import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/elements/search/place_models.dart';
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

final dioProvider = Provider<Dio>((ref){
  return Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      headers: {'User-Agent': 'OsmFlutterApp/1.0 (nilsrauschmayr@gmail.com)'},
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30)
    )
  );
});

/// Search query Notifier
final searchQueryProvider = StateProvider<String>(((ref) =>  ''));

/// Autocomplete suggestions using Photon API
final searchSuggProvider = FutureProvider.autoDispose<List<PlaceModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 3) return [];

  final dio = ref.watch(dioProvider);

  try {
    debugPrint("Searching Photon for query: '$query'");

    final response = await dio.get(
      '/api/',
      queryParameters: {
        'q': query.trim(),
        'limit': 5,
      },
    );

    debugPrint("Photon Request URL: ${response.realUri}");
    debugPrint("Photon Response status: ${response.statusCode}");

    // Safely parse response whether Dio returned a Map or a raw String
    final Map<String, dynamic> data = response.data is String
        ? jsonDecode(response.data)
        : response.data as Map<String, dynamic>;

    final features = data['features'] as List? ?? [];

    return features.map((feature) {
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;

      // ignore: prefer_interpolation_to_compose_strings
      final name = properties['name'] ?? properties['street'] + ', ' + properties['housenumber'] ?? properties['city'] ?? 'Unknown Location';
      final city = properties['city'] ?? properties['state'] ?? '';
      final country = properties['country'] ?? '';
      
      final shortName = [name]
        .where((s) => s != null && s.toString().isNotEmpty)
        .join(', ');

      final displayName = [name, city, country]
        .where((s) => s != null && s.toString().isNotEmpty && !shortName.contains(s))
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

  } on DioException catch (e) {
    debugPrint("DioError: ${e.response?.statusCode} - ${e.message}");
    return [];
  } catch (e, stackTrace) {
    debugPrint("Unknown Error: $e\n$stackTrace");
    return [];
  }
});

final selectedPlaceProvider = StateProvider<PlaceModel?>((ref) => null);