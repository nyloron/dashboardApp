import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
//-- Location State

class LocationState {
  ///current Position
  final LatLng? position;
  ///viewing direction of current position
  final double? heading;
  final double? speed; // m/s
  ///if the current location is unavailable
  final bool isLoading;
  final String? error;

  const LocationState({
    this.position,
    this.heading,
    this.speed,
    this.isLoading = false,
    this.error
  });

  ///creates a new Location State with all given values and copied all previous ones
  LocationState copyWith({
    LatLng? position,
    double? heading,
    double? speed, // m/s
    bool? isLoading,
    String? error
  }) => LocationState(
    position: position ?? this.position,
    heading: heading ?? this.heading,
    speed: speed ?? this.speed,
    isLoading: isLoading ?? this.isLoading,
    error: error
  );
}

class LocationNotifier extends StateNotifier<LocationState> {
  ///current Position subscription stream
  StreamSubscription<Position>? _sub;
  ///fires if the stream is enabled or disabled
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  ///Background retry timer, when location is missing
  Timer? _retryTimer;
  ///holds user location permission
  bool hasPermission = false;
  ///retry down ticker
  int retryTicker = 3;

  LocationNotifier() : super(const LocationState(isLoading: true)){
    //_init(); //if no function without calling init first, take out comment
    _initServiceStatusListener();
  }

  ///starts first location tracking if permission is given
  void _initServiceStatusListener(){
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if(status == ServiceStatus.enabled) refreshLocation();
    });
  }

  ///refresh location after all permissions have been loaded
  Future<void> refreshLocation() async {
    _retryTimer?.cancel(); //cancel any existing retry loop
    state = state.copyWith(isLoading: true, error: null);
    await _sub?.cancel();
    _sub = null;
    await _init();
  }

  Future<void> _init() async {
    try{
      hasPermission = await checkPermission().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch(_){
      hasPermission = false;
    }

    //return if no permission has been granted
    if(!hasPermission){
      state = state.copyWith(
        isLoading: false,
        error: 'Location permission denied or waiting for activation.',
        position: const LatLng(50.1109, 8.6821) //location fallback: Frankfurt
      );
      return;
    }

    try{
      Position? pos;
      try{
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
        //location signal timeout
        ).timeout(const Duration(seconds: 3));
      } catch(_){
        pos = await Geolocator.getLastKnownPosition();
      }

      final latLng = (pos != null)
        ? LatLng(pos.latitude, pos.longitude)
        : null; //keep null if absolutly zero location data found, retry loop after exception
      
      if(latLng == null){
        state = state.copyWith(
          isLoading: false,
          position: const LatLng(50.1109, 8.6821), //location fallback: Frankfurt
          error: 'Acquiring GPS fix...'
        );
        _startRetryLoop();
        return;
      }

      //all nessecary data is available => cancel any active retry loops
      _retryTimer?.cancel();
      _retryTimer = null;

      //copy succseful state
      state = state.copyWith(
        position: latLng,
        heading: pos?.heading ?? 0.0,
        speed: pos?.speed ?? 0.0,
        isLoading: false,
        error: null
      );
      
      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3
        )
      ).listen((pos) {
        state.copyWith(
          position: LatLng(pos.latitude, pos.longitude),
          heading: pos.heading,
          speed: pos.speed
        );
      });
      debugPrint('Location tracking stream started');

    } catch(e){
      state = state.copyWith(
        isLoading: false,
        position: const LatLng(50.1109, 8.6821), //location fallback: Frankfurt
        error: e.toString()
      );
      _startRetryLoop();
    }
  }

  ///Polls 3 times every 5 secconds, if a location is secured
  void _startRetryLoop(){
    if(_retryTimer != null && _retryTimer!.isActive) return;

    if(retryTicker > 0){
      _retryTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        debugPrint('LocationNotifier: Retrying device location setting...');

        retryTicker--;

        if(await Geolocator.isLocationServiceEnabled()){
          timer.cancel();
          _retryTimer = null;
          refreshLocation(); //GPS service enabled, fetch position
        }
      });
    }
  }

  ///checks if user location permission has been granted
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.denied){
      try{
        permission = await Geolocator.requestPermission();
      } on PermissionRequestInProgressException {
        //if permission has not been granted, dont ask again, unless the elements are reloaded
        return false;
      }
    }

    return permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
  }

  @override
  void dispose(){
    _sub?.cancel();
    _serviceStatusSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier()
);