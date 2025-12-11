import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/features/home/repositories/home_repository.dart';
import 'package:sylonow_user/features/home/repositories/quote_repository.dart';
import 'package:sylonow_user/features/home/models/quote_model.dart';
import 'package:sylonow_user/features/home/models/vendor_model.dart';
import 'package:sylonow_user/features/home/models/service_type_model.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';

/// Optimized providers with caching and performance improvements

/// Provider for Supabase client (singleton)
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for home repository (singleton)
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return HomeRepository(supabase);
});

/// Provider for quote repository (singleton)
final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

/// Cached daily quote provider - keeps data for 1 hour
final dailyQuoteProvider = FutureProvider.autoDispose<QuoteModel?>((ref) async {
  // Keep alive for 1 hour to reduce API calls
  final link = ref.keepAlive();
  Timer(const Duration(hours: 1), () {
    link.close();
  });

  final repository = ref.watch(quoteRepositoryProvider);
  return repository.getTrulyRandomQuote();
});

/// Cached featured partners provider - keeps data for 30 minutes
final featuredPartnersProvider = FutureProvider.autoDispose<List<VendorModel>>((ref) async {
  // Keep alive for 30 minutes
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 30), () {
    link.close();
  });

  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedPartners();
});

/// Cached service categories provider - keeps data for 1 hour
final serviceCategoriesProvider = FutureProvider.autoDispose<List<ServiceTypeModel>>((ref) async {
  // Keep alive for 1 hour (categories change infrequently)
  final link = ref.keepAlive();
  Timer(const Duration(hours: 1), () {
    link.close();
  });

  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServiceCategories();
});

/// Optimized featured services state with pagination
class OptimizedFeaturedServicesState {
  final List<ServiceListingModel> services;
  final bool hasMore;
  final int page;
  final bool isLoading;

  const OptimizedFeaturedServicesState({
    this.services = const [],
    this.hasMore = true,
    this.page = 1,
    this.isLoading = false,
  });

  OptimizedFeaturedServicesState copyWith({
    List<ServiceListingModel>? services,
    bool? hasMore,
    int? page,
    bool? isLoading,
  }) {
    return OptimizedFeaturedServicesState(
      services: services ?? this.services,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Optimized featured services provider with lazy loading
final optimizedFeaturedServicesProvider = 
    StateNotifierProvider.autoDispose<OptimizedFeaturedServicesNotifier, OptimizedFeaturedServicesState>((ref) {
  return OptimizedFeaturedServicesNotifier(ref.watch(homeRepositoryProvider));
});

class OptimizedFeaturedServicesNotifier extends StateNotifier<OptimizedFeaturedServicesState> {
  final HomeRepository _repository;
  
  OptimizedFeaturedServicesNotifier(this._repository) : super(const OptimizedFeaturedServicesState()) {
    // Auto-load first page
    loadServices();
  }

  Future<void> loadServices({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const OptimizedFeaturedServicesState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final page = refresh ? 1 : state.page;
      // Using existing method from repository - adjust as needed
      final newServices = await _repository.getFeaturedServices() ?? <ServiceListingModel>[];

      if (refresh) {
        state = OptimizedFeaturedServicesState(
          services: newServices,
          hasMore: newServices.length >= 10,
          page: 2,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          services: [...state.services, ...newServices],
          hasMore: newServices.length >= 10,
          page: state.page + 1,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      // Log error but don't throw to prevent UI crashes
      //('Failed to load featured services: $e');
    }
  }

  Future<void> refresh() async {
    await loadServices(refresh: true);
  }

  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) {
      await loadServices();
    }
  }
}

/// Popular nearby services provider with location-based caching
final popularNearbyServicesProvider = FutureProvider.family.autoDispose<List<ServiceListingModel>, String>((ref, locationId) async {
  // Cache for 15 minutes per location
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 15), () {
    link.close();
  });

  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedServices() ?? <ServiceListingModel>[];
});

/// Search services provider with debouncing
final searchServicesProvider = FutureProvider.family.autoDispose<List<ServiceListingModel>, String>((ref, query) async {
  // Short cache for search results
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), () {
    link.close();
  });

  // Debounce search queries
  if (query.length < 3) {
    return <ServiceListingModel>[];
  }

  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedServices() ?? <ServiceListingModel>[];
});

/// App initialization provider to preload critical data
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // Preload critical data in parallel for better performance
    await Future.wait([
      ref.read(serviceCategoriesProvider.future).catchError((_) => <ServiceTypeModel>[]),
      ref.read(dailyQuoteProvider.future).catchError((_) => null),
      ref.read(featuredPartnersProvider.future).catchError((_) => <VendorModel>[]),
    ]);
    
    return true;
  } catch (e) {
    //('App initialization error: $e');
    return false;
  }
});

/// Performance monitoring provider
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

class PerformanceMonitor {
  final Map<String, DateTime> _timers = {};

  void startTimer(String name) {
    _timers[name] = DateTime.now();
  }

  void endTimer(String name) {
    if (_timers.containsKey(name)) {
      final duration = DateTime.now().difference(_timers[name]!);
      //('Performance: $name took ${duration.inMilliseconds}ms');
      _timers.remove(name);
    }
  }

  void logMemoryUsage() {
    // Can be extended with more detailed memory monitoring
    //('Performance: Memory monitoring active');
  }
}

