import 'package:flutter/material.dart';
import 'package:flutter_app/elements/nav/map/location_provider.dart';
import 'package:flutter_app/elements/nav/search/search_bar_widget.dart';
import 'package:flutter_app/elements/nav/navigation/route_provider.dart';
import 'package:flutter_app/elements/nav/navigation/route_state.dart';
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
  Widget build(BuildContext context){
    //if the device is in Orientation.landscape
    final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final route = ref.watch(routeProvider);

    //mapPadding control
    EdgeInsets mapPadding;
    if(isLandscape){
      mapPadding = EdgeInsets.only(
        right: MediaQuery.widthOf(context) / 4.2,
        top: MediaQuery.paddingOf(context).top + 16,
        left: 16,
        bottom: 0,
      );
    } else{
      mapPadding = EdgeInsets.only(
        top: 30,
        left: 8,
        right: 8,
        bottom: (true) //route info panel logic
          ? 16+10
          : 16
      );
    }

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

              //if the map has stopped moving set _isProgrammaticMove to false, since movement of any kind has stopped
              //and since userMap movement prevention is already in place
              onCameraIdle: () => _isProgrammaticMove = false,

              //route lines drawn on map
              polylines: {
                if(route.routePoints.length >= 2)...[
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
                top: 8,
                start: 8,
                end: isLandscape
                  ? MediaQuery.widthOf(context) / 2 + 80
                  : 8,
                child: const SearchBarWidget()
              )
            ],

            //Route info panel, only visible after a destination has been selected
            if(true)...[
              PositionedDirectional(
                bottom: 16,
                start: 8,
                end: isLandscape
                  ? null
                  : 8,
                width: isLandscape
                  ? MediaQuery.widthOf(context) / 4.5
                  : null,
                child: Container(color: Colors.amber, width: 50, height: 10) //infoPanel
              )
            ]
          ],
        );
      }
    );
  }
}