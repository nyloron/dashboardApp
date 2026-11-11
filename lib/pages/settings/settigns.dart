import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/pages/index.dart';
import 'package:flutter_app/pages/settings/map_setting.dart';
import 'package:flutter_app/pages/settings/theme_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    return Scaffold(
      // AppBar handles the back button automatically when pushed with Navigator
      appBar: AppBar(
        backgroundColor: cardColor,
        title: const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      // Set ListView directly as the Scaffold body
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
          children: [
            // Theme Settings Page button
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder()
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ThemeSettings()
                  )
                );
              },
              child: ListTile(
                leading: Icon(
                  Icons.brush_sharp,
                  size: 28
                ),
                title: Text(
                  'Theme Settings',
                  style: TextStyle(
                    fontSize: 18
                  ),
                ), 
              ),
            ),
            // Map Settings Page button
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder()
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => mapSettings()
                  )
                );
              },
              child: ListTile(
                leading: Icon(
                  Icons.map_sharp,
                  size: 28
                ),
                title: Text(
                  'Map & Navigation Settings',
                  style: TextStyle(
                    fontSize: 18
                  ),
                ), 
              ),
            ),
            const Divider(),
            ValueListenableBuilder(
              valueListenable: ClockWidget.getClockFormatNotifier(),
              builder: (context, format, child) {
                return RadioGroup<bool>(
                  groupValue: format as bool,
                  onChanged: (bool? value) {
                    if (value != null) updateClockFormat(value);
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0.0, 8.0),
                        child: Text(
                          'Clock Format',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    RadioListTile(
                      title: const Text('24-hour-Format'),
                      value: true,
                    ),
                    RadioListTile(
                      title: const Text('12-hour-Format'),
                      value: false,
                    )
                  ]),
                );
              }
            ),
          ],
        )),
      )
    );
  }
}

///Mode:
///
///0 = Text Color Dark Mode; 1 = Text Color White Mode 
///
///2 = Button Color
class HexInputField extends StatefulWidget{
  final int mode;
  const HexInputField({required this.mode, super.key});

  @override
  // ignore: no_logic_in_create_state
  State<HexInputField> createState() => _HexInputField();
}

class _HexInputField extends State<HexInputField> {
  late final int mode;
  late final TextEditingController _controller;

  @override
  void initState(){
    super.initState();
    mode = widget.mode;
    _controller = TextEditingController();
    _loadSavedText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Load saved hex from local storage and pre-fill the textfield
  Future<void> _loadSavedText() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString(switch (mode) {
      0 => "textcol_dark",
      1 => "textcol_white",
      2 => "buttoncol",
      _ => throw Exception("Incorrect Stroing mode provided!")
    });

    if (savedText != null && mounted) {
      setState(() {
        _controller.text = savedText; // Pre-fills textfield with previous input
        debugPrint(savedText);
      });
    }
  }

  // Save string to local storage
  Future<void> _saveText(String value) async {
    final prefs = await SharedPreferences.getInstance();
    
    final key = switch (mode) {
      0 => "textcol_dark",
      1 => "textcol_white",
      2 => "buttoncol",
      _ => throw Exception("Incorrect Storing mode provided!"),
    };

    await prefs.setString(key, value);

    // Notify app theme to rebuild live when changing button color
    switch (mode) {
      case 0: textHexNotifierDark.value = value.isEmpty ? baseTextHexDark : value;
      case 1: textHexNotifierWhite.value = value.isEmpty ? baseTextHexWhite : value;
      case 2: buttonHexNotifier.value = value.isEmpty ? baseButtonHex : value;
    }

    debugPrint('Value for mode $mode saved as "$value"');
  }
  
  @override
  Widget build(BuildContext context){
    if(mode < 0){
      throw Exception;
    }

    return ConstrainedBox(
      constraints: BoxConstraints.tight(const Size(200, 70)),
      child: TextFormField(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'HEX',
            hintText: '#FFFFFF'  
          ),
          controller: _controller,
          maxLength: 7,
          inputFormatters: [TextInputFormatter.withFunction(((oldValue, newValue){
            final text = newValue.text;

            //Allow the chareters A-F
            if (RegExp(r'^#?[0-9a-fA-F]*$').hasMatch(text)) {
              return newValue;
            }
            return oldValue;
          }))],
          onChanged: (String? value){
            if(value == null){return;}
            final trimmed = value.trim();

            // Save empty string if field is cleared
            if (trimmed.isEmpty) {
              _saveText('');
              return;
            }

            final isValidHex = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(trimmed);

            if (isValidHex) {
              // Automatically add '#' if missing so storage is always consistent
              final formattedValue = trimmed.startsWith('#') ? trimmed : '#$trimmed';
      
              _saveText(formattedValue);
            }
          },
        ),
    );
  }
}