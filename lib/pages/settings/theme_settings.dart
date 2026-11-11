import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/pages/settings/settigns.dart';

class ThemeSettings extends StatelessWidget{
  const ThemeSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double rotateAlign = isLandscape ? 0.03 : 0.07;

    return Scaffold(
      // AppBar handles the back button automatically when pushed with Navigator
      appBar: AppBar(
        backgroundColor: cardColor,
        title: const Text('Theme Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
            SwitchListTile(
              title: Text('Dark Mode'),
              secondary: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Colors.amber,
              ),
              value: isDarkMode,
              onChanged: (val) {
                updateTheme(val);
              },
            ),
            Padding(
              padding: EdgeInsets.only(left: 10, top: 10, bottom: 20),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 11
                  ),
                  children: [
                    TextSpan(
                      text: 'Attention:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                    ),
                    TextSpan(text: ' Dark mode is '),
                    TextSpan(
                      text: 'automaticaly',
                      style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold)
                    ),
                    TextSpan(text: ' activated when your connected Map, switches to Dark mode or when your set time zone hits sunset time.')
                  ]
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0.0, 8.0),
              child: Text(
                'Colors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Table(children: [
              TableRow(children: [
                Padding(padding: EdgeInsets.only(top: 40, bottom: 40)), //vertiacal alignment of the Table Rows
                Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Text Color Dark Mode:', style: TextStyle(fontSize: 18))),
                HexInputField(mode: 0),
                Padding(padding: EdgeInsets.all(0)) //placeholder to make edge to the screen by sizing the table column
              ]),
              TableRow(children: [
                Padding(padding: EdgeInsets.only(top: 40, bottom: 40)), //vertiacal alignment of the Table Rows
                Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Text Color White Mode:', style: TextStyle(fontSize: 18))),
                HexInputField(mode: 1),
                Padding(padding: EdgeInsets.all(0)) //placeholder to make edge to the screen by sizing the table column
              ]),
              TableRow(children: [
                Padding(padding: EdgeInsets.only(top: 40, bottom: 40)), //vertiacal alignment of the Table Rows
                Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Button Color:', style: TextStyle(fontSize: 18))),
                HexInputField(mode: 2),
                Padding(padding: EdgeInsets.all(0)) //placeholder to make edge to the screen by sizing the table column
              ]),
            ],
            columnWidths: {0: FractionColumnWidth(rotateAlign), 3:FractionColumnWidth(rotateAlign)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle
            ),
            const Divider(),
          ],
        ))
      )
    );
  }
}