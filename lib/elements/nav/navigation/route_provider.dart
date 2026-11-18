import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app/elements/nav/map/location_provider.dart';
import 'package:flutter_app/elements/nav/search/search_provider.dart';
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app/elements/nav/navigation/route_state.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;

class RouteNotifier extends StateNotifier<RouteState> {
  final Ref _ref;
  ProviderSubscription? _locationSubscription;
  ///tracks consecutive GPS ticks away from the path
  int _offRouteTicker = 0;

  RouteNotifier(this._ref) : super(const RouteState()) {
    _locationSubscription = _ref.listen(locationProvider, (prev, next){
      if(state.status == NavigationStatus.navigating && next.position != null){
        final gpos = next.position!;
        _updateNavigationProgress(gpos);
      }
    });
  }

  ///initiate the navigation with a reachable current location
  void startNavigation(){
    if(state.routePoints.isEmpty) return;

    final gpos = _ref.read(locationProvider).position;
    latlong.LatLng currPos;

    if(gpos != null){
      currPos = latlong.LatLng(gpos.latitude, gpos.longitude);
    } else {
      return;
    }

    state = state.copyWith(
      status: NavigationStatus.navigating,
      markerPos: currPos,
      currentSegmentIndex: 0
    );
  }

  void stopNavigation(){
    //ToDo: insert rerouting with a override from currentPosition
  }

  void clearRoute(){
    state = const RouteState();
  }

  ///updates the navigation based on the current position
  ///by comparing it to the route points and moving forward
  void _updateNavigationProgress(latlong.LatLng currPos){
    if(state.routePoints.isEmpty) return;

    final points = state.routePoints;
    int closestSegmentIndex = state.currentSegmentIndex;
    double minDistance = double.infinity;

    //search in proximity of the currentSegmentIndex to keep tracking efficient and stable.
    //use of max and min to avoid out of bounds exception
    int start = max(0, closestSegmentIndex - 5);
    int end = min(points.length - 1, closestSegmentIndex + 15);

    //search in proximity boundries for closest to current position
    for(int i = start; i < end; i++){
      final d = haversine(currPos, points[i]);
      if(d < minDistance){
        minDistance = d;
        closestSegmentIndex = i;
      }
    }
    offRoute(minDistance, currPos);

    //calculate heading/bearing towards the next upcoming route point
    double? bear = (closestSegmentIndex < points.length - 1)
      ? bearing(points[closestSegmentIndex], points[closestSegmentIndex + 1])
      : state.markerBearing;
    
    final next = points[closestSegmentIndex + 1];
    final distToNext = haversine(currPos, next);
    //check if user is in reach of destination
    final isNextDest = points.last == next;

    //check if user has arrived within 15m of the next route point
    if(distToNext < 15.0){
      state = state.copyWith(
        markerPos: next,
        markerBearing: bear,
        status: (isNextDest) ? NavigationStatus.arrived : state.status,
        currentSegmentIndex: (isNextDest) ? points.length - 1 : closestSegmentIndex
      );
      return;
    }

    state = state.copyWith(
      markerPos: currPos,
      markerBearing: bear,
      currentSegmentIndex: closestSegmentIndex
    );
  }

  ///handles rerouting and tracking of consecutive off route navigation
  void offRoute(double minDistance, latlong.LatLng currPos){
    //return and reset counter, user has not yet deranged from path
    if(minDistance < 30.0){
      _offRouteTicker = 0;
      return;
    }
    
    _offRouteTicker++;
    debugPrint('Warning: User drifting off-route. Distance ${minDistance.toStringAsFixed(1)}m (Tick $_offRouteTicker/3)');

    //user is not far enough away from current route to ensure real off route
    if(_offRouteTicker < 3) return;

    debugPrint('Off-route confirmed, automatically recalculating route from current position initiated...');
    _offRouteTicker = 0;
  }

  Future<void> fetchRoute({latlong.LatLng? currPos}) async {
    //use the current live position if provided, otherwise fallback to locationProvider for the route Start point
    latlong.LatLng? startPos;
    if (currPos != null) {
      startPos = currPos;
    } else {
      //Wait up to 1 second (10 attempts x 100ms) for a location fix
      for (int i = 0; i < 10; i++) {
        final pos = _ref.read(locationProvider).position;
        debugPrint('Position: ${pos.toString()}');
        if (pos != null) {
          startPos = latlong.LatLng(pos.latitude, pos.longitude);
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    //read chosen destination
    final destination = _ref.read(selectedPlaceProvider)?.latLng;
    //check for null value and abort if incuficient data available
    if (destination == null || startPos == null) return;

    //check wheter its a reroute and the navigation is already running -> keep it so
    //or if its a new route -> set to load
    state = state.copyWith(status: (state.status == NavigationStatus.navigating)
      ? state.status
      : NavigationStatus.loading
    );

    ///try to get the Route from ORSM API server
    try{
      //url that provides the route from API
      final url =
        '${AppConstants.osrmBaseUrl}/${startPos.longitude},${startPos.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true';
      
      //wait for a response from the API
      final response = await http.get(Uri.parse(url));
      if(response.statusCode != 200) throw Exception('OSRM error code: ${response.statusCode}');

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      //read the first provided route out of the json to choose as default
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      List<latlong.LatLng> coords = (route['geometry']['coordinates'] as List)
        .map(
          (c) => latlong.LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble()
          )
        ).toList();

      if(state.status == NavigationStatus.navigating){
        //copy all previously passed route points to ensure a continious route
        List<latlong.LatLng> newRoute = state.routePoints.sublist(0, state.currentSegmentIndex);
        //add new route onto all previously paddes points
        newRoute.addAll(coords);
        coords = newRoute;
      }
      
      state = state.copyWith(
        routePoints: coords,
        markerPos: startPos,
        status: (state.status == NavigationStatus.navigating)
          ? NavigationStatus.navigating
          : NavigationStatus.ready,
        distanceInUnit: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
        currentSegmentIndex: (state.status == NavigationStatus.navigating)
          ? state.currentSegmentIndex
          : 0
      );
      debugPrint('Route loaded');
    } catch (e){
      state = state.copyWith(
        status: NavigationStatus.idle,
        error: 'Could not load route. Excepotion: $e. Check connection.'
      );
    }
  }

  @override
  void dispose(){
    _locationSubscription?.close();
    super.dispose();
  }
}

double bearing(latlong.LatLng from, latlong.LatLng to){
  final fLat = from.latitude * pi / 180;
  final tLat = to.latitude * pi / 180;
  final dLng = (to.longitude - from.longitude) * pi / 180;
  final y = sin(dLng) * cos(tLat);
  final x = cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>(
  (ref) => RouteNotifier(ref)
);