import 'package:flutter/material.dart';
import 'package:flutter_app/elements/navigation/route_state.dart';
import 'package:flutter_app/elements/navigation/route_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteInfoPanel extends ConsumerWidget{
  const RouteInfoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref){
    final route = ref.watch(routeProvider);

    if(route.status == NavigationStatus.idle || route.status == NavigationStatus.loading){
      return const SizedBox.shrink();
    } 

    final isNavigating = route.status == NavigationStatus.navigating;
    final isArrived = route.status == NavigationStatus.arrived;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20)
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Landscape Header
          if(MediaQuery.of(context).orientation == Orientation.landscape)...[
            Container(
              padding: const EdgeInsets.only(left: 15, right: 2),
              decoration: BoxDecoration(
                color: isArrived
                  ? Colors.green
                  : isNavigating
                  ? Colors.blue
                  : Colors.blueAccent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: Row(
              )
            )
          ]
          //Portrait Header
          else...[
            Container(
              padding: const EdgeInsets.only(left: 15, right: 2),
              decoration: BoxDecoration(
                color: isArrived
                  ? Colors.green
                  : isNavigating
                  ? Colors.blue
                  : Colors.blueAccent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: Row(
                children: [
                  Icon(
                    isArrived
                      ? Icons.check_circle_rounded
                      : isNavigating
                      ? Icons.navigation_rounded
                      : Icons.route_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArrived
                        ? "You have arrived!"
                        : isNavigating
                        ? "Navigating..."
                        : "Route ready",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15
                      ),
                    )
                  ),
                  if(!isArrived && !isNavigating) ... [
                    const SizedBox(height: 12),
                    SizedBox(
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                          .read(routeProvider.notifier)
                          .startNavigation(),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text("Start"),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 10
                          )
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: () => ref.read(routeProvider.notifier).clearRoute(),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
            ),

            // --- Stats row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Icons.straighten_rounded,
                          label: route.status == NavigationStatus.navigating
                            ? "Remaining"
                            : "Distance",
                          value: route.status == NavigationStatus.navigating
                            ? route.remainingDistanceText
                            : route.distanceText,
                          color: Colors.blue
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          icon: Icons.access_time_rounded,
                          label: route.status == NavigationStatus.navigating
                            ? "ETA"
                            : "Duration",
                          value: route.status == NavigationStatus.navigating
                            ? route.remainingDurationText
                            : route.durationText,
                          color: Colors.red
                        ),  
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}

class _Stat extends ConsumerWidget {
  final IconData? icon;
  final String? label;
  final String? value;
  final Color? color;

  const _Stat({
    this.icon,
    this.label,
    this.value,
    this.color
  });

  @override
  Widget build(BuildContext context, WidgetRef ref){
    return Column(
      children: [
        if(icon != null)...[
          Icon(
            icon,
          )
        ],
        if(label != null)...[
          Text(
            label!,
            style: TextStyle(
              color: color
            ),
          )
        ],
        if(value != null)...[
          Text(
            value!,
            style: TextStyle(
              color: color
            ),
          )
        ],
      ],
    );
  }
}