import 'package:flutter/material.dart';
import 'package:flutter_app/elements/navigation/route_state.dart';
import 'package:flutter_app/elements/navigation/route_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteInfoPanel extends ConsumerWidget{
  const RouteInfoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref){
    final route = ref.watch(routeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    if(route.status == NavigationStatus.idle || route.status == NavigationStatus.loading){
      return const SizedBox.shrink();
    } 

    final isNavigating = route.status == NavigationStatus.navigating;
    final isArrived = route.status == NavigationStatus.arrived;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20)
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Header
          Container(
            padding: const EdgeInsets.only(left: 15, right: 2),
            decoration: BoxDecoration(
              color: isArrived
                ? Colors.green
                : isNavigating
                ? Theme.of(context).colorScheme.primary
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
                  icon: Icon(
                    Icons.cancel_outlined,
                    //color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          ),
          //Landscape Stats Column
          if(MediaQuery.of(context).orientation == Orientation.landscape)...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                        ..._Stat(
                        iconData: Icons.straighten_rounded,
                        label: route.status == NavigationStatus.navigating
                          ? "Remaining:"
                          : "Distance:",
                        value: route.status == NavigationStatus.navigating
                          ? route.remainingDistanceText
                          : route.distanceText,
                        color: Colors.blue
                      ).build(context),
                      //const Spacer()
                    ]
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                        ..._Stat(
                        iconData: Icons.access_time_rounded,
                        label: route.status == NavigationStatus.navigating
                          ? "ETA:"
                          : "Duration:",
                        value: route.status == NavigationStatus.navigating
                          ? route.remainingDurationText
                          : route.durationText,
                        color: Colors.red
                      ).build(context),
                      //const Spacer()
                    ]
                  ),
                  const SizedBox(height: 12),
                ]
              )
            )
          ]
          //Portrait Stats row
          else...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: _Stat(
                            iconData: Icons.straighten_rounded,
                            label: route.status == NavigationStatus.navigating
                              ? "Remaining"
                              : "Distance",
                            value: route.status == NavigationStatus.navigating
                              ? route.remainingDistanceText
                              : route.distanceText,
                            color: Colors.blue
                          ).build(context)
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            children: _Stat(
                            iconData: Icons.access_time_rounded,
                            label: route.status == NavigationStatus.navigating
                              ? "ETA"
                              : "Duration",
                            value: route.status == NavigationStatus.navigating
                              ? route.remainingDurationText
                              : route.durationText,
                            color: Colors.red
                          ).build(context)
                        )
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

class _Stat {
  final IconData? iconData;
  final String? label;
  final String? value;
  final Color? color;

  const _Stat({
    this.iconData,
    this.label,
    this.value,
    this.color,
  });

  List<Widget> build(BuildContext context){
    return [
      if(iconData != null)...[
        Icon(
          iconData,
        )
      ],
      SizedBox(width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 12 : 0, height: (MediaQuery.of(context).orientation == Orientation.landscape) ? 12 : 0),
      if(label != null)...[
        Text(
          label!,
          textAlign: (MediaQuery.of(context).orientation == Orientation.landscape) ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold
          ),
        )
      ],
      if(MediaQuery.of(context).orientation == Orientation.landscape) const Spacer(),
      if(value != null)...[
        Text(
          value!,
          style: TextStyle(
            color: color
          ),
        )
      ],
    ];
  }
}