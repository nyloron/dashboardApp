import 'package:flutter/material.dart';
import 'package:flutter_app/elements/nav/map/location_provider.dart';
import 'package:flutter_app/elements/nav/map/map_controller_provider.dart';
import 'package:flutter_app/elements/nav/search/search_bar_widget.dart';
import 'package:flutter_app/elements/nav/navigation/route_provider.dart';
import 'package:flutter_app/elements/nav/navigation/route_state.dart';
import 'package:flutter_app/elements/nav/search/search_provider.dart';
import 'package:flutter_app/elements/nav/navigation/route_info_panel.dart';
import 'package:flutter_app/elements/utils/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GMaps extends ConsumerStatefulWidget {
  static final ValueNotifier<MapType> mapTypeNotifier = ValueNotifier(MapType.normal);
  const GMaps({super.key});

  @override
  ConsumerState<GMaps> createState() => _GMaps();
}

class _GMaps extends ConsumerState<GMaps> {
  ///states if loading of the map is complete
  bool _mapReady = false;
  ///tracks if the user has manually dragged/planned the map away.
  bool _userHasMovedMap = false;
  ///prevents programmatic camera movements from being mistaken for gestures.
  bool _isProgrammaticMove = false;
  ///to ensure a smooth transition, should the device orientation change.
  Orientation? _lastOrientation;

  @override
  void initState(){
    super.initState();

    final route = ref.read(routeProvider);

    //handle location following controll
    ref.listenManual(locationProvider, (previous, next) {
      if (!_mapReady) return;

      //apply camera logic here
      if(!_userHasMovedMap){
        _isProgrammaticMove = true;
        return;
      }
    });
  }

  @override
  Widget build(BuildContext context){
    //if the device is in Orientation.landscape
    final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final route = ref.watch(routeProvider);
    final destination = ref.watch(selectedPlaceProvider);

    //mapPadding control
    EdgeInsets mapPadding;
    if(isLandscape){
      mapPadding = EdgeInsets.only(
        left: MediaQuery.widthOf(context) / 4.2,
        top: (route.status == NavigationStatus.ready
          || route.status == NavigationStatus.navigating
          || route.status == NavigationStatus.arrived
        )
          ? MediaQuery.paddingOf(context).top + 16
          //to keep reatio while hiding ugly map credit
          : -32,
        right: 16,
        bottom: (route.status == NavigationStatus.ready
          || route.status == NavigationStatus.navigating
          || route.status == NavigationStatus.arrived
        )
          ? 0
          //to keep reatio while hiding ugly map credit
          : -32,
      );
    } else{
      mapPadding = EdgeInsets.only(
        top: (route.status != NavigationStatus.navigating) ? 30 : 16,
        left: 8,
        right: 8,
        bottom: (route.status == NavigationStatus.ready
          || route.status == NavigationStatus.navigating
          || route.status == NavigationStatus.arrived
        )
          ? 16+150
          : 0
      );
    }
    debugPrint(route.status.toString());

    //return ValueListenableBuilder to change the map type according to the setting chosen by the user
    return ValueListenableBuilder(
      valueListenable: GMaps.mapTypeNotifier,
      builder: (context, type, child){
        //return Stack to display controls above the map
        return Stack(
          children: [
            //actual map element
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: ref.watch(locationProvider).position ?? const LatLng(50.1109, 8.6821),
                zoom: AppConstants.defaultZoom,
                tilt: 0
              ),
              padding: mapPadding,
              minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
              //Map settings
              buildingsEnabled: true,
              myLocationEnabled: true, //add true if navigation is not active, when active use custom nav marker for heading
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              webCameraControlEnabled: false,
              fortyFiveDegreeImageryEnabled: true,
              trafficEnabled: true,
              mapId: '1879cb7727ee28b712665690',
              //according to the user setting
              mapType: type,

              //handle user and software camera movement distinction
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
              //if the map has stopped moving set _isProgrammaticMove to false, since movement of any kind has stopped
              //and since userMap movement prevention is already in place
              onCameraIdle: () => _isProgrammaticMove = false,

              onMapCreated: (controller) {
                ref.read(mapControllerProvider.notifier).state = controller;
                _mapReady = true;
              },

              markers: {
                if(destination != null && route.status != NavigationStatus.idle)...[
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(
                      destination.latLng.latitude,
                      destination.latLng.longitude
                    )
                  )
                ]
              },

              //route lines drawn on map
              polylines: {
                if(route.routePoints.length >= 2 && route.status == NavigationStatus.navigating)...[
                  Polyline(
                    polylineId: const PolylineId('main route'),
                    points: route.routePoints.map(
                      (p) => LatLng(
                        p.latitude,
                        p.longitude
                      )
                    ).toList(),
                    width: 5,
                    endCap: Cap.roundCap,
                    startCap: Cap.roundCap,
                    color: const Color(0xFF440DFA)
                  )
                ]
              },
            ),

            //search bar
            if(route.status != NavigationStatus.navigating)...[
              PositionedDirectional(
                top: 16,
                start: 16,
                end: isLandscape
                  ? MediaQuery.widthOf(context) / 2 + 80
                  : 16,
                child: const SearchBarWidget()
              )
            ],

            //Route info panel, only visible after a destination has been selected
            PositionedDirectional(
              bottom: 16,
              start: 16,
              end: isLandscape
                ? null
                : 16,
              width: isLandscape
                ? MediaQuery.widthOf(context) / 4.5
                : null,
              child: RouteInfoPanel()
            )
          ],
        );
      }
    );
  }
}