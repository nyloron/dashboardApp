import 'dart:math';
import 'package:flutter/material.dart';

// Animated user location pulse
class UserLocationMarker extends StatefulWidget{
  final double heading;

  const UserLocationMarker({super.key, this.heading = 0});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker> with SingleTickerProviderStateMixin{
  late AnimationController _pulse;

  @override
  void initState(){
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2)
    )..repeat();
  }

  @override
  void dispose(){
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child){
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Transform.scale(
              scale: 1 + _pulse.value * 0.8,
              child: Opacity(
                opacity: (1 - _pulse.value) * 0.4,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent
                  ),
                ),
              ),
            ),
            // Inner dot with heading arrow
            Transform.rotate(angle: widget.heading * pi / 180, child: child!)
          ],
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(
            color: Colors.blueAccent.withAlpha(100),
            blurRadius: 8,
            spreadRadius: 2
          )]
        ),
        child: const Icon(
          Icons.navigation_rounded,
          size: 10,
          color: Colors.white
        ),
      ),
    );
  }
}