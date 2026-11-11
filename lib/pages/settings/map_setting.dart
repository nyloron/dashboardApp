import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/custom_img_button.dart';
import 'package:flutter_app/elements/map/g_maps_osrm.dart';
import 'package:flutter_app/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: must_be_immutable, camel_case_types
class mapSettings extends StatelessWidget{
  int _selectedIndex = (GMapsOsrm.mapTypeNotifier.value == MapType.normal) ? 0 
    : ((GMapsOsrm.mapTypeNotifier.value == MapType.hybrid)) ? 1 
    : (GMapsOsrm.mapTypeNotifier.value == MapType.terrain) ? 2
    : 0;

  mapSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    return Scaffold(
      // AppBar handles the back button automatically when pushed with Navigator
      appBar: AppBar(
        backgroundColor: cardColor,
        title: const Text('Map & Navigation Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Positive velocity means dragging left-to-right
          if (details.primaryVelocity != null && details.primaryVelocity! > 300){
            if(Navigator.canPop(context)){
              Navigator.pop(context);
            }
          }
        },
        child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<MapType>(
              valueListenable: GMapsOsrm.mapTypeNotifier,
              builder: (context, type, child){
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0, 16.0),
                      child: Text(
                        'Map Type',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),
                      )
                    ),
                    Row(
                      children: [
                        const Spacer(flex: 2),
                        ImgButton(
                          image: Image(
                            image: AssetImage('assets/images/normal-map-type.png'),
                            width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 150 : 100,
                          ),
                          isSelected: _selectedIndex == 0,
                          child: Text('Normal'),
                          onTap: () {
                            _selectedIndex = 0;
                            updateMapType(MapType.normal);
                          },
                        ),
                        const Spacer(),
                        ImgButton(
                          image: Image(
                            image: AssetImage('assets/images/hybrid-map-type.png'),
                            width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 150 : 100,
                          ),
                          isSelected: _selectedIndex == 1,
                          child: Text('Satellite'),
                          onTap: () {
                            _selectedIndex = 1;
                            updateMapType(MapType.hybrid);
                          },
                        ),
                        const Spacer(),
                        ImgButton(
                          image: Image(
                            image: AssetImage('assets/images/terrain-map-type.png'),
                            width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 150 : 100,
                          ),
                          isSelected: _selectedIndex == 2,
                          child: Text('Terrain'),
                          onTap: () {
                            _selectedIndex = 2;
                            updateMapType(MapType.terrain);
                          },
                        ),
                        const Spacer(flex: 2)
                      ]
                    ),
                    Padding(padding: EdgeInsets.only(bottom: 16)),
                    Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            text: 'Graphics: @terraink.app',
                            style: TextStyle(fontSize: 8),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final Uri url = Uri.parse('https://terraink.app');
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  debugPrint('Could not launch URL: $e');
                                }
                              }
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ]
                );
              }
            ),
            const Divider(),
            ValueListenableBuilder(
              valueListenable: unitNotifier,
              builder: (context, currentUnit, child) {
                return RadioGroup<Units>(
                  groupValue: currentUnit,
                  onChanged: (Units? value) {
                    if (value != null) updateUnit(value);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0.0, 8.0),
                        child: Text(
                          'Unit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      RadioListTile<Units>(
                        title: const Text('Metric'),
                        value: Units.metric,
                      ),
                      RadioListTile<Units>(
                        title: const Text('Imperial'),
                        value: Units.imperial,
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
          ],
        )),
      ),
    );
  }
}