import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapControls extends ConsumerWidget {
  final VoidCallback onTap; // <--- Make sure this is stored/used

  const MapControls({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recenter
        _ControlButton(
          icon: Icons.my_location_rounded,
          tooltip: 'MyLocation',
          onTap: onTap, // <--- Use the passed callback here!
        )
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}