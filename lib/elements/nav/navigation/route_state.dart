import 'dart:math';

import 'package:flutter_app/main.dart';
import 'package:latlong2/latlong.dart' as latlong;

///state of an Route
enum NavigationStatus {
  ///destination chosen, route remains idle
  idle,
  ///route is loading
  loading,
  ///route has been loaded and navigation is ready to be started
  ready,
  ///user is currently navigating to destination
  navigating,
  ///user has arrived at destination
  arrived
}

///attibutes of an Route
class RouteState {
  ///location points that make up a route
  final List<latlong.LatLng> routePoints;
  ///position of the user location marker
  final latlong.LatLng? markerPos;
  final double? markerBearing;
  ///state of the route
  final NavigationStatus status;
  ///remaining distance in meters or feet according to user setting
  final double? distanceInUnit;
  ///remaining duration in seconds
  final double? durationSeconds;
  ///index of the current routePoint that the user has last crossed location with
  final int currentSegmentIndex;
  final String? error;

  const RouteState({
    this.routePoints = const [],
    this.markerPos,
    this.markerBearing,
    this.status = NavigationStatus.idle,
    this.distanceInUnit,
    this.durationSeconds,
    this.currentSegmentIndex = 0,
    this.error
  });

  ///creates a new RouteStates with a copy of all attributes not declared otherwise
  RouteState copyWith({
    List<latlong.LatLng>? routePoints,
    latlong.LatLng? markerPos,
    double? markerBearing,
    NavigationStatus? status,
    double? distanceInUnit,
    double? durationSeconds,
    int? currentSegmentIndex,
    String? error
  }) => RouteState(
    routePoints: routePoints ?? this.routePoints,
    markerPos: markerPos ?? this.markerPos,
    markerBearing: markerBearing ?? this.markerBearing,
    status: status ?? this.status,
    distanceInUnit: distanceInUnit ?? this.distanceInUnit,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
    error: error
  );

  ///returns the full distance as a String
  String get distanceText{
    if(distanceInUnit == null) return "";
    if(distanceInUnit! >= 1000){
      if(unitNotifier.value == Units.metric) return '${(distanceInUnit! / 1000).toStringAsFixed(1)} km';
      return '${((distanceInUnit! / 1000) * 0.621371).toStringAsFixed(1)} m';
    }
    if(unitNotifier.value == Units.metric) return '${distanceInUnit!.toStringAsFixed(0)} m';
    return '${(distanceInUnit! * 3.28084).toStringAsFixed(0)} feet';
  }

  ///returns the full duration as a String
  String get durationText{
    if(durationSeconds == null) return '';
    final mins = (durationSeconds! / 60).round();
    if(mins >= 60){
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h}h ${m}m';
    }
    return '$mins min';
  }

  ///returns the remaining distance as a double
  double get remainingDistanceDouble{
    if(routePoints.isEmpty || currentSegmentIndex >= routePoints.length) return double.parse(distanceText);

    double remainingMeters = 0.0;
    for(int i = currentSegmentIndex; i < routePoints.length - 1; i++){
      remainingMeters += haversine(routePoints[i], routePoints[i + 1]);
    }

    return remainingMeters;
  }

  ///returns the remaining distance as a String
  String get remainingDistanceText{
    if(remainingDistanceDouble >= 1000){
      if(unitNotifier.value == Units.metric) return '${(remainingDistanceDouble / 1000).toStringAsFixed(1)} km';
      return '${((remainingDistanceDouble / 1000) * 0.621371).toStringAsFixed(1)} m';
    }
    if(unitNotifier.value == Units.metric) return '${remainingDistanceDouble.toStringAsFixed(0)} m';
    return '${(remainingDistanceDouble * 3.28084).toStringAsFixed(0)} feet';
  }

  ///returns the remaining duration as a String
  String get remainingDurationText{
    if(durationSeconds == null || distanceInUnit != null || distanceInUnit! <= 0) return durationText;
    
    //scale remaining time proportionally based on OSRM' total speed ratio
    final mins = (remainingDistanceDouble * (durationSeconds! / distanceInUnit!) / 60).round();
    if(mins >= 60){
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h}h ${m}m';
    }
    return '$mins min';
  }
}

///calcualtes the distance between two locations
double haversine(latlong.LatLng a, latlong.LatLng b){
  ///earths radius
  const R = 6371000.0;
  final aLat = a.latitude * pi / 180;
  final bLat = a.latitude * pi / 180;
  final dlat = (b.latitude - a.latitude) * pi / 180;
  final dlng = (b.longitude - a.longitude) * pi / 180;
  final s =
    sin(dlat / 2) * sin(dlat / 2) +
    cos(aLat) * cos(bLat) * sin(dlng / 2) * sin(dlng / 2);
  return R * 2 * atan2(sqrt(s), sqrt(1 - s));
}