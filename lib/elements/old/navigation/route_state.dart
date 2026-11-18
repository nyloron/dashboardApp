import 'dart:math';

import 'package:flutter_app/main.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' as latlong;

enum NavigationStatus { idle, loading, ready, navigating, arrived }

class RouteState {
  final List<LatLng> routePoints;
  final LatLng? markerPos;
  final double? markerBearing;
  final NavigationStatus status;
  /// meters or feet
  final double? distanceUnit;
  final double? durationSeconds;
  final int currentSegmentIndex;
  final String? error;

  const RouteState({
    this.routePoints = const [],
    this.markerPos,
    this.markerBearing,
    this.status = NavigationStatus.idle,
    this.distanceUnit,
    this.durationSeconds,
    this.currentSegmentIndex = 0,
    this.error
  });

  RouteState copyWith({
    List<LatLng>? routePoints,
    LatLng? markerPos,
    double? markerBearing,
    NavigationStatus? status,
    double? distanceUnit,
    double? durationSeconds,
    int? currentSegmentIndex,
    String? error
  }) => RouteState(
    routePoints: routePoints ?? this.routePoints,
    markerPos: markerPos ?? this.markerPos,
    markerBearing: markerBearing ?? this.markerBearing,
    status: status ?? this.status,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
    error: error
  );

  String get distanceText{
    if(distanceUnit == null) return "";
    if(distanceUnit! >= 1000){
      if(unitNotifier.value == Units.metric) return '${(distanceUnit! / 1000).toStringAsFixed(1)} km';
      return '${((distanceUnit! / 1000) * 0.621371).toStringAsFixed(1)} m';
    }
    if(unitNotifier.value == Units.metric) return '${distanceUnit!.toStringAsFixed(0)} m';
    return '${(distanceUnit! * 3.28084).toStringAsFixed(0)} feet';
  }

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

  double get remainingDistanceDouble{
    if(routePoints.isEmpty || currentSegmentIndex >= routePoints.length) return double.parse(distanceText);

    double remainingMeters = 0.0;
    for(int i = currentSegmentIndex; i < routePoints.length - 1; i++){
      remainingMeters += _haversine(routePoints[i], routePoints[i + 1]);
    }

    return remainingMeters;
  }

  String get remainingDistanceText{
    if(remainingDistanceDouble >= 1000){
      if(unitNotifier.value == Units.metric) return '${(remainingDistanceDouble / 1000).toStringAsFixed(1)} km';
      return '${((remainingDistanceDouble / 1000) * 0.621371).toStringAsFixed(1)} m';
    }
    if(unitNotifier.value == Units.metric) return '${remainingDistanceDouble.toStringAsFixed(0)} m';
    return '${(remainingDistanceDouble * 3.28084).toStringAsFixed(0)} feet';
  }

  String get remainingDurationText{
    if(durationSeconds == null || distanceUnit != null || distanceUnit! <= 0) return durationText;
    
    //scale remaining time proportionally based on OSRM' total speed ratio
    final mins = (remainingDistanceDouble * (durationSeconds! / distanceUnit!) / 60).round();
    if(mins >= 60){
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h}h ${m}m';
    }
    return '$mins min';
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
}