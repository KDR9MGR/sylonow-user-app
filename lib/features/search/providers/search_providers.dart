import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/home/repositories/home_repository.dart';
import 'package:sylonow_user/features/home/providers/optimized_home_providers.dart';

/// Search providers with offline cache, debounce, and lazy loading

/// Provider for search repository
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final homeRepository = ref.watch(homeRepositoryProvider);
  return SearchRepository(homeRepository);
});

/// Cached search results provider with debouncing
final searchResultsProvider = FutureProvider.family.autoDispose<List<ServiceListingModel>, String>((ref, query) async {
  // Debounce: Cancel previous request if a new one is made within 300ms
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  
  // Wait for debounce period
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Check if request was cancelled
  if (cancelToken.isCancelled) {
    return <ServiceListingModel>[];
  }
  
  // Keep search results cached for 10 minutes
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 10), () {
    link.close();
  });

  final repository = ref.watch(searchRepositoryProvider);
  return repository.searchServices(query, cancelToken: cancelToken);
});

/// Recent searches provider with local storage
final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

/// Cancel token for cancelling ongoing requests
class CancelToken {
  bool _isCancelled = false;
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    _isCancelled = true;
  }
}

/// Recent searches notifier with persistent storage
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  RecentSearchesNotifier() : super([]) {
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchesJson = prefs.getStringList(_storageKey) ?? [];
      state = searchesJson.take(_maxRecentSearches).toList();
    } catch (e) {
      //('Failed to load recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, state);
    } catch (e) {
      //('Failed to save recent searches: $e');
    }
  }

  void add(String search) {
    if (search.trim().isEmpty) return;
    
    final normalizedSearch = search.trim().toLowerCase();
    final currentList = [...state];
    
    // Remove if already exists
    currentList.removeWhere((item) => item.toLowerCase() == normalizedSearch);
    
    // Add to beginning
    currentList.insert(0, search.trim());
    
    // Keep only max items
    if (currentList.length > _maxRecentSearches) {
      currentList.removeRange(_maxRecentSearches, currentList.length);
    }
    
    state = currentList;
    _saveRecentSearches();
  }

  void remove(String search) {
    state = state.where((item) => item != search).toList();
    _saveRecentSearches();
  }

  void clearAll() {
    state = [];
    _saveRecentSearches();
  }
}

/// Search repository with offline caching
class SearchRepository {
  final HomeRepository _homeRepository;
  static const String _cacheKey = 'search_cache';
  
  // In-memory cache for search results
  final Map<String, CacheEntry<List<ServiceListingModel>>> _searchCache = {};

  SearchRepository(this._homeRepository);

  /// Search services with caching
  Future<List<ServiceListingModel>> searchServices(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final cacheKey = query.toLowerCase().trim();
    
    // Check in-memory cache first
    if (_searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
      if (!cached.isExpired) {
        //('Returning cached search results for: $query');
        return cached.data;
      } else {
        _searchCache.remove(cacheKey);
      }
    }

    // Check if request was cancelled
    if (cancelToken?.isCancelled == true) {
      return <ServiceListingModel>[];
    }

    try {
      // Perform actual search
      //('Performing live search for: $query');
      final results = await _performLiveSearch(query);
      
      // Check if request was cancelled before caching
      if (cancelToken?.isCancelled == true) {
        return <ServiceListingModel>[];
      }

      // Cache results
      _searchCache[cacheKey] = CacheEntry(
        data: results,
        timestamp: DateTime.now(),
        duration: const Duration(minutes: 10),
      );

      return results;
    } catch (e) {
      //('Search error: $e');
      return <ServiceListingModel>[];
    }
  }

  /// Perform live search using the home repository
  Future<List<ServiceListingModel>> _performLiveSearch(String query) async {
    try {
      // Get all services from the home repository
      final allServices = await _homeRepository.getFeaturedServices() ?? <ServiceListingModel>[];
      
      // Simple text matching
      final filteredServices = allServices.where((service) {
        final searchLower = query.toLowerCase();
        return service.name.toLowerCase().contains(searchLower) ||
               (service.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      return filteredServices;
    } catch (e) {
      //('Live search error: $e');
      return <ServiceListingModel>[];
    }
  }
}

/// Cache entry with expiration
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration duration;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.duration,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > duration;
}