import 'package:flutter/material.dart';
import 'package:flutter_app/taskbar.dart'; // Access themeNotifier
import 'package:flutter_app/pages/settings/settigns.dart';
import 'package:clock/clock.dart';
import 'package:flutter_app/elements/map/g_maps_osrm.dart';
import 'dart:async';

class Index extends StatelessWidget {
  const Index({super.key});

  @override
  Widget build(BuildContext context) {
    // Automatically detects if dark mode is active from the current theme
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    return Scaffold(
      appBar: AppBar(
            backgroundColor: cardColor,
            actions: [
              Padding(padding: EdgeInsets.only(left: (MediaQuery.of(context).orientation == Orientation.landscape) ? 5 : 0)),
              Padding(
                padding: EdgeInsets.only(
                  left: (MediaQuery.of(context).orientation == Orientation.landscape) ? 10 : 5,
                  right: (MediaQuery.of(context).orientation == Orientation.landscape) ? 0 : 5
                ),
                child: ClockWidget()
              ),
              const Spacer(),
              Taskbar(),
              const Spacer(),              //Settings Button
              IconButton(
                padding: EdgeInsets.all(5),
                icon: Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage()
                    )
                  );
                },
              ),
              Padding(padding: EdgeInsets.only(right: (MediaQuery.of(context).orientation == Orientation.landscape) ? 5 : 0)),
            ],
          ),
      body: Column(
        children: [
          // lib/pages/index.dart
          Expanded(
            child: GMapsOsrm(), // ProviderScope now only lives around the map
          ),
          //Expanded(
            //child: GoogleMapOsrmPage()
          //)
        ],
      )
    );
  }
}

class ClockWidget extends StatefulWidget{
  static final ValueNotifier<bool> clockFormat = ValueNotifier(true);
  const ClockWidget({super.key});

  static ValueNotifier getClockFormatNotifier(){
    return clockFormat;
  }

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}
class _ClockWidgetState extends State<ClockWidget>{
  late Timer _timer;
  late DateTime _currTime;
  
  @override
  void initState() {
    super.initState();
    _currTime = clock.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer){
      if(mounted){
        setState(() {
          _currTime = clock.now();
        });
      }
    });
  }
  @override
  void dispose(){
    _timer.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    return ValueListenableBuilder<bool>(
      valueListenable: ClockWidget.clockFormat,
      builder: (context, is24Hour, child){
        final h = _currTime.hour.toString().padLeft(2, "0");
        final min = _currTime.minute.toString().padLeft(2, "0");

        if(is24Hour){
          return Text(
          '$h:$min',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          );
        }
        else{
          final h12 = (_currTime.hour % 12 == 0) ? (12).toString().padLeft(2, "0") : (_currTime.hour % 12).toString().padLeft(2, "0");
          if(MediaQuery.of(context).orientation == Orientation.landscape){
            final dayTime = (_currTime.hour >= 12) ? 'pm' : 'am';
            return Text(
              '$h12:$min $dayTime',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          } else{
            final dayTime = (_currTime.hour >= 12) ? 'PM' : 'AM';
            return Text(
              '$h12:$min\n$dayTime',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            );
          }
        }
      }
    );
  }
}