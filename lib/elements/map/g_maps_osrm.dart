import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app/elements/map/location_provider.dart';
import 'package:flutter_app/elements/map/map_controller_provider.dart';
import 'package:flutter_app/elements/map/map_controls.dart';
import 'package:flutter_app/elements/navigation/route_state.dart';
import 'package:flutter_app/elements/navigation/route_provider.dart';
import 'package:flutter_app/elements/navigation/route_info_panel.dart';
import 'package:flutter_app/elements/search/search_provider.dart';
import 'package:flutter_app/elements/search/search_bar_widget.dart';
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as osm;

class GMapsOsrm extends ConsumerStatefulWidget {
  static final ValueNotifier<MapType> mapTypeNotifier =
      ValueNotifier(MapType.normal);

  const GMapsOsrm({super.key});

  @override
  ConsumerState<GMapsOsrm> createState() => _GMapsOsrm();
}

class _GMapsOsrm extends ConsumerState<GMapsOsrm> {
  bool _mapReady = false;

  // Tracks if the user has manually dragged/panned the map away.
  bool _userHasMovedMap = false;

  // Prevents programmatic camera movements from being mistaken for gestures.
  bool _isProgrammaticMove = false;

  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    
    // Follow GPS only while no route is being displayed.
    ref.listenManual(locationProvider, (previous, next) {
      if (!_mapReady) return;

      final currentRoute = ref.read(routeProvider);

      if (next.position != null && !_userHasMovedMap && currentRoute.status != NavigationStatus.ready){
        _isProgrammaticMove = true;
        if (currentRoute.status != NavigationStatus.navigating) {
          _moveToLocation(next.position!);
        } else{
          _handleNavigatingCamera(currentRoute);
        }
      }
    });

    // Respond to route changes.
    ref.listenManual(routeProvider, (previous, next) {
      final routeChanged = previous == null ||
          previous.routePoints != next.routePoints;

      // Automatically frame the complete route when it becomes ready.
      if ((next.status == NavigationStatus.ready || next.status == NavigationStatus.idle) &&
          next.routePoints.isNotEmpty &&
          routeChanged) {
        _fitRouteOnMap(next.routePoints);
      }

      // Follow the moving marker during navigation.
      if (next.status == NavigationStatus.navigating && !_userHasMovedMap) {
        _handleNavigatingCamera(next);
      }
    });
  }

  void _onMapReady() {
    setState(() => _mapReady = true);

    final route = ref.read(routeProvider);

    // If a route already exists, show the entire route.
    if (route.routePoints.isNotEmpty &&
        (route.status == NavigationStatus.ready ||
            route.status == NavigationStatus.loading)) {
      _fitRouteOnMap(route.routePoints);
      return;
    }

    // Otherwise, start at the current location.
    final pos = ref.read(locationProvider).position;
    if (pos != null) {
      _moveToLocation(pos);
    }
  }

  /// Moves the camera to the current location.
  Future<void> _moveToLocation(LatLng pos) async {
    final controller = ref.read(mapControllerProvider);
    if (controller == null || !_mapReady) return;

    //_isProgrammaticMove = true;

    try {
      await controller.moveSmooth(
        pos,
        zoom: AppConstants.defaultZoom,
        tilt: 65.0,
      );
    } catch (e) {
      debugPrint('Failed to move to location: $e');
      _isProgrammaticMove = false;
    }
  }

  /// Follows the navigation marker while navigation is active.
  void _handleNavigatingCamera(RouteState route) {
    if (!_mapReady || route.status != NavigationStatus.navigating) return;

    final controller = ref.read(mapControllerProvider);
    if (controller == null) return;

    final p = ref.read(locationProvider).position!;
    final double heading = route.markerBearing ?? 0.0;

    if(!_userHasMovedMap) {
      controller.moveSmooth(
        LatLng(p.latitude, p.longitude),
        zoom: AppConstants.routeZoom,
        tilt: 65.0,
        bearing: heading
      );
    }
  }

  /// Fits the entire OSRM route inside the visible map safely.
  Future<void> _fitRouteOnMap(List<osm.LatLng> routePoints) async {
    if (!_mapReady || routePoints.isEmpty) return;

    final controller = ref.read(mapControllerProvider);
    if (controller == null) return;

    // Wait for the current frame to finish layout before touching bounds
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small safety delay to ensure native view dimensions are non-zero
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      if (routePoints.length == 1) {
        _isProgrammaticMove = true;
        try {
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(
                routePoints.first.latitude,
                routePoints.first.longitude,
              ),
              16,
            ),
          );
        } catch (e) {
          debugPrint('Failed to focus single route point: $e');
          _isProgrammaticMove = false;
        }
        return;
      }

      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;

      for (final point in routePoints) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat-0.035, minLng-0.035),
        northeast: LatLng(maxLat, maxLng),
      );

      _isProgrammaticMove = true;

      try {
        // Animate camera to fit the bounds with 80px padding
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 0),
        );
      } catch (e) {
        debugPrint('Failed to fit route bounds, retrying in 300ms: $e');
        
        // Fallback retry if native layout was still sizing up
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        
        try {
          await controller.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 0),
          );
        } catch (retryError) {
          debugPrint('Route bounds fit failed permanently: $retryError');
          _isProgrammaticMove = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(selectedPlaceProvider);
    final route = ref.watch(routeProvider);

    EdgeInsets mapPadding;
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      mapPadding = EdgeInsets.only(
        left: MediaQuery.widthOf(context) / 4.2, // Matches RouteInfoPanel width
        top: MediaQuery.paddingOf(context).top + 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      );
    } else {
      mapPadding = EdgeInsets.only(
        top: route.status != NavigationStatus.navigating 
            ? MediaQuery.paddingOf(context).top + 70 // Clearance for search bar
            : MediaQuery.paddingOf(context).top + 16,
        bottom: 230, // Clearance for RouteInfoPanel card at the bottom
        left: 16,
        right: 16,
      );
    }

    return ValueListenableBuilder<MapType>(
      valueListenable: GMapsOsrm.mapTypeNotifier,
      builder: (context, type, child) {
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: ref.read(locationProvider).position ??
                    const LatLng(50.1109, 8.6821),
                zoom: AppConstants.defaultZoom,
                tilt: 65.0,
              ),
              padding: mapPadding,
              minMaxZoomPreference:
                  const MinMaxZoomPreference(0, 21),
              buildingsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              fortyFiveDegreeImageryEnabled: false,
              trafficEnabled: true,
              mapId: '1879cb7727ee28b712665690',
              mapType: type,

              onCameraMoveStarted: () {
                if (!_isProgrammaticMove && _lastOrientation == MediaQuery.orientationOf(context)) {
                  setState(() {
                    _userHasMovedMap = true;
                  });
                } else{
                  setState(() {
                    _lastOrientation = MediaQuery.orientationOf(context);
                  });
                }
              },

              onCameraIdle: () {
                _isProgrammaticMove = false;
              },

              onMapCreated: (controller) {
                ref.read(mapControllerProvider.notifier).state =
                    controller;
                _onMapReady();
              },

              markers: {
                if (destination != null &&
                    route.status != NavigationStatus.navigating)
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(
                      destination.latLng.latitude,
                      destination.latLng.longitude,
                    ),
                  ),
              },

              polylines: {
                if (route.routePoints.length >= 2) ...[
                  Polyline(
                    polylineId: const PolylineId('Shadow'),
                    points: route.routePoints
                        .map(
                          (p) => LatLng(
                            p.latitude,
                            p.longitude,
                          ),
                        )
                        .toList(),
                    width: 8,
                    color: Colors.black.withAlpha(20),
                  ),
                  Polyline(
                    polylineId: const PolylineId('main route'),
                    points: route.routePoints
                        .map(
                          (p) => LatLng(
                            p.latitude,
                            p.longitude,
                          ),
                        )
                        .toList(),
                    width: 5,
                    endCap: Cap.roundCap,
                    startCap: Cap.roundCap,
                    color: const Color(0xFF440DFA),
                  ),
                ],
              },
            ),

            // Search bar.
            if(route.status != NavigationStatus.navigating)...[
              PositionedDirectional(
                top: MediaQuery.of(context).padding.top + 8,
                start: 8,
                end: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? MediaQuery.sizeOf(context).width / 2 + 80
                    : (_userHasMovedMap ? 80 : 8),
                child: const SearchBarWidget(),
              )
            ],

            // Recenter button.
            Positioned(
              right: 8,
              top: 8,
              child: _userHasMovedMap
                  ? MapControls(
                      onTap: () {
                        setState(() {
                          _userHasMovedMap = false;
                          _isProgrammaticMove = true;
                        });

                        final currentRoute = ref.read(routeProvider);

                        if (currentRoute.status == NavigationStatus.ready) {
                          _fitRouteOnMap(currentRoute.routePoints);
                        } else {
                          final pos =
                              ref.read(locationProvider).position;

                          if (pos != null) {
                            if(currentRoute.status == NavigationStatus.navigating){
                              _handleNavigatingCamera(route);
                            } else{
                              _moveToLocation(pos);
                            }
                          }
                        }
                      },
                    )
                  : const SizedBox.shrink(),
            ),

            if(route.status == NavigationStatus.loading)...[
              const Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text("Finding best route...")
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            
            PositionedDirectional(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              start: 8,
              end: MediaQuery.of(context).orientation == Orientation.landscape
                  ? null
                  : 8,
              width: MediaQuery.of(context).orientation == Orientation.landscape ? MediaQuery.widthOf(context) / 4.5 : null,
              child: const RouteInfoPanel(),
            ),

            if(route.error != null)...[
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      route.error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              )
            ]
          ],
        );
      },
    );
  }
}
