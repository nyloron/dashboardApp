import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app/elements/nav/map/location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app/elements/nav/navigation/route_state.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:latlong2/latlong.dart' as latlong;

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
    void startNevigation(){
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
      offRoute(minDistance);

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
    void offRoute(double minDistance){
      //return and reset counter, user has not yet deranged from path
      if(minDistance < 30.0){
        _offRouteTicker = 0;
        return;
      }
      
      _offRouteTicker++;
      debugPrint('Warning: User drifting off-route. Distance ${minDistance.toStringAsFixed(1)}m (Tick $_offRouteTicker/3)');

      //user is not far enough away from current route to ensure real off path
      if(_offRouteTicker < 3) return;

      debugPrint('Off-route confirmed, automatically recalculating route from current position initiated...');
      _offRouteTicker = 0;

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