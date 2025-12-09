import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/theater_screen_model.dart';
import '../models/screen_category_model.dart';
import '../services/theater_service.dart';
import '../../address/providers/address_providers.dart';

// Service provider
final theaterServiceProvider = Provider<TheaterService>((ref) {
  return TheaterService();
});

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Theater screens provider with location-based filtering
final theaterScreensProvider = FutureProvider<List<TheaterScreen>>((ref) async {
  final service = ref.read(theaterServiceProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);

  // If user has selected an address, use location-based filtering
  if (selectedAddress != null &&
      selectedAddress.latitude != null &&
      selectedAddress.longitude != null) {
    return await service.fetchTheaterScreensWithLocation(
      userLat: selectedAddress.latitude,
      userLon: selectedAddress.longitude,
      radiusKm: 60.0, // Default 60km radius for theaters
    );
  }

  // Fallback to original method without location filtering
  return await service.fetchTheaterScreensWithPricing();
});

// Screen categories provider
final screenCategoriesProvider = FutureProvider<List<ScreenCategory>>((ref) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('screen_category')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return (response as List)
        .map((json) => ScreenCategory.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching screen categories: $e');
    return [];
  }
});

// Filtered screens provider for better performance
final filteredTheaterScreensProvider = Provider.family<List<TheaterScreen>, FilterParams>((ref, params) {
  final screens = ref.watch(theaterScreensProvider).value ?? [];

  var filteredScreens = screens.where((screen) {
    // Filter out screens with no pricing (no time slots added)
    // This ensures the screen has at least one time slot in theater_time_slots table
    final hasValidPrice = screen.basePrice != null && screen.basePrice! > 0;

    // Search filter - searches in screen name, theater name, and description
    final matchesSearch = params.searchQuery.isEmpty ||
        screen.screenName.toLowerCase().contains(params.searchQuery.toLowerCase()) ||
        (screen.theaterName?.toLowerCase().contains(params.searchQuery.toLowerCase()) ?? false) ||
        (screen.description?.toLowerCase().contains(params.searchQuery.toLowerCase()) ?? false);

    // Price filter - use basePrice if available, otherwise use hourlyRate
    final priceToCheck = screen.basePrice ?? screen.hourlyRate;
    final matchesPrice = priceToCheck >= params.minPrice && priceToCheck <= params.maxPrice;

    // Category filter
    final matchesCategory = params.selectedCategories.isEmpty ||
        (screen.categoryId != null && params.selectedCategories.contains(screen.categoryId));

    // Distance filter - now uses actual distance data from location-based query
    final matchesDistance = screen.distanceKm == null || screen.distanceKm! <= params.maxDistance;

    return hasValidPrice && matchesSearch && matchesPrice && matchesCategory && matchesDistance;
  }).toList();

  // Apply sorting - use basePrice if available, otherwise use hourlyRate
  if (params.selectedSort == 'high_to_low') {
    filteredScreens.sort((a, b) {
      final priceA = a.basePrice ?? a.hourlyRate;
      final priceB = b.basePrice ?? b.hourlyRate;
      return priceB.compareTo(priceA);
    });
  } else if (params.selectedSort == 'low_to_high') {
    filteredScreens.sort((a, b) {
      final priceA = a.basePrice ?? a.hourlyRate;
      final priceB = b.basePrice ?? b.hourlyRate;
      return priceA.compareTo(priceB);
    });
  }

  return filteredScreens;
});

// Filter parameters class
class FilterParams {
  final String searchQuery;
  final String selectedSort; // 'high_to_low' or 'low_to_high'
  final List<String> selectedCategories;
  final double minPrice;
  final double maxPrice;
  final double maxDistance;

  const FilterParams({
    required this.searchQuery,
    required this.selectedSort,
    this.selectedCategories = const [],
    this.minPrice = 0,
    this.maxPrice = 10000,
    this.maxDistance = 60,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterParams &&
        other.searchQuery == searchQuery &&
        other.selectedSort == selectedSort &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.maxDistance == maxDistance &&
        _listEquals(other.selectedCategories, selectedCategories);
  }

  @override
  int get hashCode =>
      searchQuery.hashCode ^
      selectedSort.hashCode ^
      minPrice.hashCode ^
      maxPrice.hashCode ^
      maxDistance.hashCode ^
      selectedCategories.fold(0, (prev, element) => prev ^ element.hashCode);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}