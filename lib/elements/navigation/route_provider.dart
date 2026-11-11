import 'dart:convert';
import 'dart:math';

import 'package:flutter_app/elements/map/location_state.dart';
import 'package:flutter_app/elements/map/location_provider.dart';
import 'package:flutter_app/elements/search/search_provider.dart';
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app/elements/navigation/route_state.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
// ignore: unused_import
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' as gmaps;

class RouteNotifier extends StateNotifier<RouteState> {
  final Ref _ref;
  ProviderSubscription? _locationSubscription;

  RouteNotifier(this._ref) : super(const RouteState()) {
    // Automatically listen to live GPS position updates from locationProvider
    _locationSubscription = _ref.listen<LocationState>(locationProvider, (prev, next) {
      if (state.status == NavigationStatus.navigating && next.position != null) {
        final gpos = next.position!;
        // Convert Google Maps LatLng -> latlong2 LatLng safely
        final converted = latlong.LatLng(gpos.latitude, gpos.longitude);
        _updateNavigationProgress(converted);
      }
    });
  }

  Future<void> fetchRoute() async {
    final location = _ref.read(locationProvider).position;
    final destination = _ref.read(selectedPlaceProvider);

    if (location == null || destination == null) return;

    state = state.copyWith(status: NavigationStatus.loading, error: null);

    try {
      final url =
        '${AppConstants.osrmBaseUrl}/${location.longitude},${location.latitude};'
        '${destination.latLng.longitude},${destination.latLng.latitude}'
        '?overview=full&geometries=geojson&steps=true';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('OSRM error');

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      final coords = (route['geometry']['coordinates'] as List)
        .map(
          (c) => latlong.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())
        )
        .toList();
      
      state = state.copyWith(
        routePoints: coords,
        markerPos: coords.first,
        status: NavigationStatus.ready,
        distanceUnit: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
        currentSegmentIndex: 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: NavigationStatus.idle,
        error: 'Could not load route. Check connection.',
      );
    }
  }

  void startNavigation() {
    if (state.routePoints.isEmpty) return;

    final gpos = _ref.read(locationProvider).position;
    latlong.LatLng currentPos;
    
    if (gpos != null) {
      currentPos = latlong.LatLng(gpos.latitude, gpos.longitude);
    } else {
      currentPos = state.routePoints.first;
    }

    state = state.copyWith(
      status: NavigationStatus.navigating,
      markerPos: currentPos,
      currentSegmentIndex: 0,
    );
  }

  void _updateNavigationProgress(latlong.LatLng currentPos) {
    if (state.routePoints.isEmpty) return;

    final points = state.routePoints;
    int closestSegmentIndex = state.currentSegmentIndex;
    double minDistance = double.infinity;

    // Search around the current segment index to keep tracking efficient and stable
    int searchStart = max(0, state.currentSegmentIndex - 2);
    int searchEnd = min(points.length - 1, state.currentSegmentIndex + 15);

    for (int i = searchStart; i < searchEnd; i++) {
      final d = _haversine(currentPos, points[i]);
      if (d < minDistance) {
        minDistance = d;
        closestSegmentIndex = i;
      }
    }

    // Calculate heading/bearing towards the next upcoming route point
    double? bearing;
    if (closestSegmentIndex < points.length - 1) {
      bearing = _bearing(points[closestSegmentIndex], points[closestSegmentIndex + 1]);
    }

    // Check if user has arrived within 15m of the next destination point
    final next = points[closestSegmentIndex + 1];
    final distToNext = _haversine(currentPos, next);

    // Check if user is in reach of destination
    if (points.last == next && distToNext < 15.0) {
      state = state.copyWith(
        markerPos: next,
        status: NavigationStatus.arrived,
        currentSegmentIndex: points.length - 1,
      );
      return;
    }

    state = state.copyWith(
      markerPos: currentPos,
      markerBearing: bearing ?? state.markerBearing,
      currentSegmentIndex: closestSegmentIndex,
    );
  }

  void stopNavigation() {
    state = const RouteState();
  }

  void clearRoute() {
    state = const RouteState();
  }

  double _haversine(latlong.LatLng a, latlong.LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dlat = (b.latitude - a.latitude) * pi / 180;
    final dlng = (b.longitude - a.longitude) * pi / 180;
    final s =
      sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1) * cos(lat2) * sin(dlng / 2) * sin(dlng / 2);
    return R * 2 * atan2(sqrt(s), sqrt(1 - s));
  }

  double _bearing(latlong.LatLng from, latlong.LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dlng = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dlng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  void dispose() {
    _locationSubscription?.close();
    super.dispose();
  }
}

final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>(
  (ref) => RouteNotifier(ref),
);