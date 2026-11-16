import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceModel {
  final String displayName;
  final String shortName;
  final LatLng latLng;
  ///Type of place (e.g. Hospital, restraurant)
  final String? type;
  final String? icon;

  const PlaceModel({
    required this.displayName,
    required this.shortName,
    required this.latLng,
    this.type,
    this.icon
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json){
    return PlaceModel(
      displayName: json['display_name'] as String,
      shortName: _extractShortName(json['display_name'] as String),
      latLng: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String)
      ),
      type: json['type'] as String?,
      icon: json['icon'] as String?
    );
  }

  static String _extractShortName(String displayname){
    final parts = displayname.split(',');
    return parts.length >= 2
      ? '${parts[0].trim()}, ${parts[1].trim()}'
      : parts[0].trim();
  }
}