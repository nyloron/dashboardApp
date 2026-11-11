import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_app/elements/map/location_provider.dart';
import 'package:flutter_app/elements/map/map_controller_provider.dart';
import 'package:flutter_app/elements/navigation/route_provider.dart';
import 'package:flutter_app/elements/search/place_models.dart';
import 'package:flutter_app/elements/search/search_provider.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

class SearchBarWidget extends ConsumerStatefulWidget{
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget>{
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void dispose(){
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value){
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = value;
      setState(() => _showSuggestions = value.length >= 3);
    });
  }

  void _onSelectPlace(PlaceModel place){
    _controller.text = place.shortName;
    _focus.unfocus();
    setState(() => _showSuggestions = false);

    ref.read(selectedPlaceProvider.notifier).state = place;
    ref.read(routeProvider.notifier).fetchRoute();

    //final mapController = ref.read(mapControllerProvider);
    //mapController?.moveSmooth(place.latLng, zoom: 14);
  }

  void _clearSearch(){
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedPlaceProvider.notifier).state = null;
    ref.read(routeProvider.notifier).clearRoute();
    ref.read(mapControllerProvider)?.moveCamera(CameraUpdateNewLatLng(ref.read(locationProvider).position!));
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context){
    final suggestions = ref.watch(searchSuggProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = (buttonHexNotifier.value.toColor(fallback: const Color(0xFF4BAEA0)).computeLuminance() > 0.98 || buttonHexNotifier.value.toColor(fallback: const Color(0xFF4BAEA0)).computeLuminance() < 0.02)? const Color(0xFF4BAEA0) : buttonHexNotifier.value.toColor(fallback: const Color(0xFF4BAEA0));
    final cardColor = isDarkMode ? const Color.fromARGB(255, 16, 16, 16) : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search input
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 2)
            )]
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search destination...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: iconColor
              ),
              suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded)
                )
                : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14
              )
            ),
          ),
        ),

        // Suggestions dropdown
        if(_showSuggestions)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.of(context).orientation == Orientation.landscape) ? 250 : MediaQuery.sizeOf(context).height/2.6, // Strict compact limit so it never overflows the screen bottom
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                  color: Colors.black12,
                )]
              ),
              child: Material(
                type: MaterialType.transparency,
                child: suggestions.when(
                  data: (places) {
                    if(places.isEmpty){
                      return const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No results found.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true, // Shrinks to fit items if fewer than 250px, scrolls if more
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return _SuggestionTile(
                          place: place,
                          onTap: () => _onSelectPlace(place)
                        )
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (index * 40).ms)
                        .slideY(begin: 0.1, end: 0);
                      },
                      separatorBuilder: (buildContext, ints) => const Divider(
                        height: 1,
                        indent: 52,
                      ),
                      itemCount: places.length,
                    );
                  },
                  error: (buildContext, ints) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Search failed. Try again.'),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget{
  final PlaceModel place;
  final VoidCallback onTap;

  const _SuggestionTile({required this.place, required this.onTap});
  static const List<({List<String> keywords, IconData icon, Color? color})> _iconRules = [
    //Sustenance
    (keywords: ['restaurant'], icon: Icons.restaurant_rounded, color: Colors.deepOrange),
    (keywords: ['cafe'], icon: Icons.local_cafe_rounded, color: Colors.deepOrange),
    (keywords: ['fast_food', 'food_court'], icon: Icons.fast_forward_rounded, color: Colors.deepOrange),
    (keywords: ['bar', 'pub', 'biergarten'], icon: Icons.local_bar_rounded, color: Colors.deepOrange),
    (keywords: ['ice_cream'], icon: Icons.icecream_rounded, color: Colors.deepOrange),
    //Accommodation
    (keywords: ['otel'/*use of otel to include all*/], icon: Icons.hotel_rounded, color: Colors.pinkAccent),
    (keywords: ['chalet', 'alpine_hut', 'camp_site', 'caravan_site'], icon: Icons.cabin_rounded, color: Colors.pinkAccent),
    (keywords: ['attraction', 'viewpoint'], icon: Icons.camera_enhance_rounded, color: Colors.pinkAccent),
    (keywords: ['museum', 'artwork'], icon: Icons.museum_rounded, color: Colors.pinkAccent),
    //Shopping
    (keywords: ['supermarkt', 'mall'], icon: Icons.shopping_cart_rounded, color: Colors.blueAccent),
    (keywords: ['conveinience'], icon: Icons.store_rounded, color: Colors.blueAccent),
    (keywords: ['bakery', 'butcher', 'greengrocer'], icon: Icons.bakery_dining_rounded, color: Colors.blueAccent),
    (keywords: ['clothes', 'shoes', 'boutique'], icon: Icons.checkroom_rounded, color: Colors.blueAccent),
    (keywords: ['shop'], icon: Icons.shopping_bag_rounded, color: Colors.blueAccent),
    //Health & Emergency
    (keywords: ['hospital'], icon: Icons.local_hospital_rounded, color: Colors.redAccent),
    (keywords: ['clinic', 'doctors', 'dentist'], icon: Icons.medical_services_rounded, color: Colors.redAccent),
    (keywords: ['pharmacy'], icon: Icons.local_pharmacy_rounded, color: Colors.redAccent),
    (keywords: ['veterinary'], icon: Icons.pets_rounded, color: Colors.redAccent),
    (keywords: ['police'], icon: Icons.local_police_rounded, color: Colors.redAccent),
    (keywords: ['fire_station'], icon: Icons.local_fire_department_rounded, color: Colors.redAccent),
    //Education
    (keywords: ['school', 'university', 'college', 'kindergarten'], icon: Icons.school_rounded, color: Colors.blueGrey),
    (keywords: ['libary'], icon: Icons.book_rounded, color: Colors.blueGrey),
    //Waste Management
    (keywords: ['sanitray_dump_station', 'recycling', 'waste'], icon: Icons.delete_rounded, color: Colors.blueGrey),
    //Transportation & Infrastructure
    (keywords: ['fuel'], icon: Icons.local_gas_station_rounded, color: Colors.indigoAccent),
    (keywords: ['parking'], icon: Icons.local_parking_rounded, color: Colors.indigoAccent),
    (keywords: ['charging_station'], icon: Icons.ev_station_rounded, color: Colors.indigoAccent),
    (keywords: ['aerialway', 'aero', 'airport'], icon: Icons.flight_rounded, color: Colors.indigoAccent),
    (keywords: ['bus_station', 'train_station'], icon: Icons.directions_transit_rounded, color: Colors.indigoAccent),
    (keywords: ['bank', 'atm'], icon: Icons.account_balance_rounded, color: Colors.indigoAccent),
    //Leisure, Parks & Sports
    (keywords: ['park', 'nature_reserve'], icon: Icons.park_rounded, color: Colors.green),
    (keywords: ['sports_centre', 'pitch', 'stadium', 'fitness_centre', 'gym'], icon: Icons.location_on_rounded, color: Colors.green),
    (keywords: ['swimming_pool'], icon: Icons.pool_rounded, color: Colors.green),
    (keywords: ['cinema', 'theatre'], icon: Icons.movie_rounded, color: Colors.green),
    //Geographic & Administrative Places
    (keywords: ['city'], icon: Icons.location_city_rounded, color: null),
    (keywords: ['town', 'village', 'hamlet'], icon: Icons.home_rounded, color: null),
    (keywords: ['neighbourhood', 'suburb'], icon: Icons.place_rounded, color: null),
    (keywords: ['residential', 'secondary', 'highway'], icon: Icons.alt_route_rounded, color: null),
  ];


  Icon _iconForType(String? type) {
    final t = type?.toLowerCase() ?? '';
    
    for (final rule in _iconRules) {
      if (rule.keywords.any((keyword) => t.contains(keyword))) {
        return Icon(rule.icon, size: 18, color: rule.color);
      }
    }

    return const Icon(
      Icons.location_on_rounded,
      size: 18,
    );
  }

  @override
  Widget build(BuildContext context){
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10)
        ),
        child: _iconForType(place.type)
      ),
      title: Text(
        place.shortName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        place.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }
}