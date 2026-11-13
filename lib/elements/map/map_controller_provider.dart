// Map controller singelton
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final mapControllerProvider = StateProvider<GoogleMapController?>((ref) => null);

// Map layer toggle (OSM / Satelite)
final isSatelliteProvider = StateProvider<bool>((ref) => false);

extension MapControllerX on GoogleMapController {
  Future<void> moveSmooth(LatLng center, {double zoom = AppConstants.defaultZoom, double tilt = 45.0, double bearing = 0}) async {
    await animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: center,
          zoom: zoom,
          tilt: tilt,
          bearing: bearing
        )
      )
    );
  }
}