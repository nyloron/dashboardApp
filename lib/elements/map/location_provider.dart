import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/elements/map/location_state.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationNotifier extends StateNotifier<LocationState> {
  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  Timer? _retryTimer; // <--- Background retry timer when location is missing
  bool hasPermission = false;

  LocationNotifier() : super(const LocationState(isLoading: true)) {
    _init();
    _initServiceStatusListener();
  }

  void _initServiceStatusListener() {
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        refreshLocation();
      }
    });
  }

  Future<void> refreshLocation() async {
    _retryTimer?.cancel(); // Cancel any existing retry loop
    state = state.copyWith(isLoading: true, error: null);
    await _sub?.cancel();
    _sub = null;
    await _init();
  }

  Future<void> _init() async {
    try {
      hasPermission = await checkPermission().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (_) {
      hasPermission = false;
    }

    if (!hasPermission) {
      state = state.copyWith(
        isLoading: false,
        error: 'Location permission denied or waiting for activation.',
        position: const LatLng(50.1109, 8.6821), // Frankfurt fallback
      );
      _startRetryLoop(); // <--- Keep trying in the background if permission is missing
      return;
    }

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      final latLng = (pos != null)
        ? LatLng(pos.latitude, pos.longitude)
        : null; // Keep null if absolute zero position found so retry loop handles it

      if (latLng == null) {
        state = state.copyWith(
          isLoading: false,
          position: const LatLng(50.1109, 8.6821),
          error: 'Acquiring GPS fix...',
        );
        _startRetryLoop();
        return;
      }

      // Success! Cancel any active retry loops since we have a fix
      _retryTimer?.cancel();
      _retryTimer = null;

      state = state.copyWith(
        position: latLng,
        heading: pos?.heading ?? 0.0,
        speed: pos?.speed ?? 0.0,
        isLoading: false,
        error: null,
      );
      
      _startStream();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        position: const LatLng(50.1109, 8.6821),
        error: e.toString(),
      );
      _startRetryLoop(); // <--- Retry on exception as well
    }
  }

  // Polls every 5 seconds until a valid location/permission is secured
  void _startRetryLoop() {
    if (_retryTimer != null && _retryTimer!.isActive) return;

    _retryTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      debugPrint("LocationNotifier: Retrying location check...");
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (serviceEnabled && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
        timer.cancel();
        _retryTimer = null;
        refreshLocation(); // Permission/GPS now available, fetch position!
      }
    });
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      state = state.copyWith(
        position: LatLng(pos.latitude, pos.longitude),
        heading: pos.heading,
        speed: pos.speed,
      );
    });
    debugPrint("Location tracking stream started");
  }

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
      } on PermissionRequestInProgressException {
        await Future.delayed(const Duration(milliseconds: 500));
        permission = await Geolocator.checkPermission();
      }
    }

    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _serviceStatusSub?.cancel();
    _retryTimer?.cancel(); // <--- Clean up timer on dispose
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);