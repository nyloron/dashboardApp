// lib/elements/utils/app_constants.dart

class AppConstants {
  // OSRM routing API (free, no key needed)
  static const String osrmBaseUrl = 
    'https://router.project-osrm.org/route/v1/driving';
  
  // Nominatim search API (free, no key needed)
  static const String baseUrl = 'https://photon.komoot.io';

  // Animation durations
  static const Duration marketAnimDuration = Duration(milliseconds: 50);
  static const Duration cameraAnimDuration = Duration(milliseconds: 600);
  static const Duration routeDrawDuration = Duration(milliseconds: 1200);

  static const double defaultZoom = 18.0;
  static const double routeZoom = 20.0;
}