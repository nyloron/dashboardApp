import 'package:flutter/material.dart';
import 'package:flutter_app/elements/map/g_maps_osrm.dart';
import 'package:flutter_app/pages/index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

enum Units {metric, imperial}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark); //set Value that can be changed everywhere in the app
final ValueNotifier<Units> unitNotifier = ValueNotifier(Units.metric); //set Value that can be changed everywhere in the app
final ValueNotifier<String> buttonHexNotifier = ValueNotifier(baseButtonHex);
final ValueNotifier<String> textHexNotifierDark = ValueNotifier(baseTextHexDark);
final ValueNotifier<String> textHexNotifierWhite = ValueNotifier(baseTextHexWhite);

const String baseButtonHex = '4BAEA0';
const String baseTextHexDark = 'FFFFFF';
const String baseTextHexWhite = '000000';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);  //Enter Fullscreen

  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
    await mapsImplementation.warmup();
  }

  // 1. Load saved theme preference on startup (defaults to dark mode if not set)
  final prefs = await SharedPreferences.getInstance();

  //Theme
  final isDarkMode = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // read the unit (metric or imperial)
  final unit = prefs.getString('unit');
  if(unit != null && Units.values.byName(unit) == Units.imperial){
    unitNotifier.value = Units.imperial;
  } else{
    unitNotifier.value = Units.metric;
  }

  //read custom button color
  final String? savedButtonCol = prefs.getString('buttoncol');
  buttonHexNotifier.value = (savedButtonCol != null && savedButtonCol.isNotEmpty) ? savedButtonCol : baseButtonHex;

// Load text saved colors
  final String? savedTextDark = prefs.getString('textcol_dark');
  textHexNotifierDark.value = (savedTextDark != null && savedTextDark.isNotEmpty) ? savedTextDark : baseTextHexDark;

  final String? savedTextWhite = prefs.getString('textcol_white');
  textHexNotifierWhite.value = (savedTextWhite != null && savedTextWhite.isNotEmpty) ? savedTextWhite : baseTextHexWhite;

  //Clock Format
  ClockWidget.clockFormat.value = prefs.getBool('ClockFormat')?? true ;

  //Map Type
  String type = prefs.getString('MapType')?? 'normal';
  GMapsOsrm.mapTypeNotifier.value = (type == 'normal') ? .normal 
    : (type == 'hybrid') ? .hybrid
    : (type == 'terrain') ? .terrain
    : .normal;

  runApp(
    const ProviderScope(  // <--- ADD THIS WRAPPER
      child: MyApp(),
    ),
  );
}

/// Helper function to change and persist the theme setting
Future<void> updateTheme(bool isDark) async {
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDarkMode', isDark);
}

/// write unit settings (true = metric; false = freedom units)
void updateUnit(Units units) async {
  if(units == Units.metric){
    unitNotifier.value = Units.metric;
  } else{
    unitNotifier.value = Units.imperial;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('unit', units.name);
}

/// Helper function to update button color and trigger live theme updates
Future<void> updateButtonColor(String hex) async {
  buttonHexNotifier.value = hex.isEmpty ? baseButtonHex : hex;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('buttoncol', hex);
}

/// Helper function to update button color and trigger live theme updates
Future<void> updateTextColor(String hex) async {
  textHexNotifierDark.value = hex.isEmpty ? baseTextHexDark : hex;
  textHexNotifierWhite.value = hex.isEmpty ? baseTextHexWhite : hex;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('textcol_dark', hex);
  await prefs.setString('textcol_white', hex);
}

/// Helper function to update clock foramt and trigger live updates
void updateClockFormat(bool clockFormat) async {
    final prefs = await SharedPreferences.getInstance();
    ClockWidget.getClockFormatNotifier().value = clockFormat;
    await prefs.setBool('ClockFormat', clockFormat);
}

/// Helper function to update clock foramt and trigger live updates
void updateMapType(MapType type) async {
    final prefs = await SharedPreferences.getInstance();
    GMapsOsrm.mapTypeNotifier.value = type;
    await prefs.setString('MapType', type.name);
}

extension HexColor on String {
  /// Converts a hex string (`#FFF`, `#FFFFFF`, or `0xFFFFFFFF`) directly to a [Color].
  /// Returns [fallback] if parsing fails.
  Color toColor({Color fallback = Colors.transparent}) {
    String clean = replaceAll('#', '').replaceAll('0x', '').trim();

    // Expand 3-digit hex (#FFF -> FFFFFF)
    if (clean.length == 3) {
      clean = clean.split('').map((c) => '$c$c').join();
    }

    // Add full opacity (FF) if no alpha channel is provided
    if (clean.length == 6) {
      clean = 'FF$clean';
    }

    if (clean.length == 8) {
      final value = int.tryParse(clean, radix: 16);
      if (value != null) return Color(value);
    }

    return fallback;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier, buttonHexNotifier,
        textHexNotifierDark,
        textHexNotifierWhite
      ]),
      builder: (context, child) {
        final currentMode = themeNotifier.value;

        // Parse hex directly into a Flutter Color using the extension
        final buttonColor = buttonHexNotifier.value.toColor(fallback: const Color(0xFF4BAEA0));
        final textColorDark = textHexNotifierDark.value.toColor(fallback: const Color(0xFF000000));
        final textColorWhite = textHexNotifierWhite.value.toColor(fallback: const Color(0xFFFFFFFF));

        // Use fallback seed if color is near-monochrome to avoid M3 blue fallback
        final seedColor = (buttonColor.computeLuminance() > 0.98 || buttonColor.computeLuminance() < 0.02)? const Color(0xFF4BAEA0) : buttonColor;

        return MaterialApp(
          theme: ThemeData(
            scaffoldBackgroundColor: const Color.fromARGB(255, 221, 221, 221),
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            ).copyWith(primary: buttonColor),
            textTheme: ThemeData.light().textTheme.apply(
              bodyColor: textColorWhite,
              displayColor: textColorWhite
            ),
            // Sets text color for RadioListTile, SwitchListTile, and ListTile titles
            listTileTheme: ListTileThemeData(
              textColor: textColorWhite,
              iconColor: textColorWhite,
            )
          ),
          darkTheme: ThemeData(
            scaffoldBackgroundColor: const Color.fromARGB(255, 40, 40, 40),
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ).copyWith(primary: buttonColor),
            textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: textColorDark,
              displayColor: textColorDark
            ),
            listTileTheme: ListTileThemeData(
              textColor: textColorDark,
              iconColor: textColorDark,
            )
          ),
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const Index(),
        );
      },
    );
  }
}