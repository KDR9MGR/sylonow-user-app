import 'dart:async';
import 'dart:convert';
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

/// Search suggestions provider
final searchSuggestionsProvider = FutureProvider.family.autoDispose<List<String>, String>((ref, query) async {
  if (query.length < 2) return <String>[];
  
  final repository = ref.watch(searchRepositoryProvider);
  return repository.getSearchSuggestions(query);
});

/// Search filter state
class SearchFilterState {
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final String? sortBy;
  final String? location;

  const SearchFilterState({
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.sortBy,
    this.location,
  });

  SearchFilterState copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? sortBy,
    String? location,
  }) {
    return SearchFilterState(
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      sortBy: sortBy ?? this.sortBy,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'minRating': minRating,
      'sortBy': sortBy,
      'location': location,
    };
  }

  factory SearchFilterState.fromJson(Map<String, dynamic> json) {
    return SearchFilterState(
      category: json['category'] as String?,
      minPrice: json['minPrice'] != null ? (json['minPrice'] as num).toDouble() : null,
      maxPrice: json['maxPrice'] != null ? (json['maxPrice'] as num).toDouble() : null,
      minRating: json['minRating'] != null ? (json['minRating'] as num).toDouble() : null,
      sortBy: json['sortBy'] as String?,
      location: json['location'] as String?,
    );
  }
}

/// Search filters provider
final searchFiltersProvider = StateNotifierProvider<SearchFiltersNotifier, SearchFilterState>((ref) {
  return SearchFiltersNotifier();
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

/// Search filters notifier
class SearchFiltersNotifier extends StateNotifier<SearchFilterState> {
  SearchFiltersNotifier() : super(const SearchFilterState());

  void updateCategory(String? category) {
    state = state.copyWith(category: category);
  }

  void updatePriceRange(double? minPrice, double? maxPrice) {
    state = state.copyWith(minPrice: minPrice, maxPrice: maxPrice);
  }

  void updateMinRating(double? minRating) {
    state = state.copyWith(minRating: minRating);
  }

  void updateSortBy(String? sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void updateLocation(String? location) {
    state = state.copyWith(location: location);
  }

  void clearFilters() {
    state = const SearchFilterState();
  }
}

/// Search repository with offline caching
class SearchRepository {
  final HomeRepository _homeRepository;
  static const String _cacheKey = 'search_cache';
  
  // In-memory cache for search results
  final Map<String, CacheEntry<List<ServiceListingModel>>> _searchCache = {};
  
  // Cache for suggestions
  final Map<String, CacheEntry<List<String>>> _suggestionsCache = {};

  SearchRepository(this._homeRepository);

  /// Search services with caching
  Future<List<ServiceListingModel>> searchServices(
    String query, {
    SearchFilterState? filters,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = _generateCacheKey(query, filters);
    
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
      // Try to get from offline cache first
      final offlineResults = await _getOfflineSearchResults(query);
      if (offlineResults.isNotEmpty) {
        //('Returning offline cached results for: $query');
        return _applyFilters(offlineResults, filters);
      }

      // Check if request was cancelled
      if (cancelToken?.isCancelled == true) {
        return <ServiceListingModel>[];
      }

      // Perform actual search
      //('Performing live search for: $query');
      final results = await _performLiveSearch(query, filters);
      
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

      // Save to offline cache
      _saveOfflineSearchResults(query, results);

      return results;
    } catch (e) {
      //('Search error: $e');
      // Return empty list on error
      return <ServiceListingModel>[];
    }
  }

  /// Get search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    final normalizedQuery = query.toLowerCase().trim();
    
    // Check cache
    if (_suggestionsCache.containsKey(normalizedQuery)) {
      final cached = _suggestionsCache[normalizedQuery]!;
      if (!cached.isExpired) {
        return cached.data;
      }
    }

    // Generate suggestions based on popular searches and cached data
    final suggestions = <String>[];
    
    // Add predefined popular searches that match
    const popularSearches = [
      'Birthday Decoration',
      'Anniversary Setup', 
      'Wedding Decoration',
      'Baby Shower',
      'Corporate Events',
      'Theme Parties',
      'Home Cleaning',
      'AC Repair',
      'Plumbing',
      'Electrical Work',
      'Painting',
      'Interior Design',
      'Catering',
      'Photography',
      'DJ Services',
    ];

    for (final search in popularSearches) {
      if (search.toLowerCase().contains(normalizedQuery)) {
        suggestions.add(search);
      }
    }

    // Limit to 8 suggestions
    final limitedSuggestions = suggestions.take(8).toList();

    // Cache suggestions
    _suggestionsCache[normalizedQuery] = CacheEntry(
      data: limitedSuggestions,
      timestamp: DateTime.now(),
      duration: const Duration(hours: 1),
    );

    return limitedSuggestions;
  }

  /// Perform live search using the home repository
  Future<List<ServiceListingModel>> _performLiveSearch(
    String query,
    SearchFilterState? filters,
  ) async {
    // For now, we'll simulate search by getting featured services
    // and filtering them. In a real app, this would be a proper search API call.
    final allServices = await _homeRepository.getFeaturedServices() ?? <ServiceListingModel>[];
    
    // Simple text matching
    final filteredServices = allServices.where((service) {
      final searchLower = query.toLowerCase();
      return service.name.toLowerCase().contains(searchLower) ||
             (service.description?.toLowerCase().contains(searchLower) ?? false);
    }).toList();

    return _applyFilters(filteredServices, filters);
  }

  /// Apply filters to search results
  List<ServiceListingModel> _applyFilters(
    List<ServiceListingModel> services,
    SearchFilterState? filters,
  ) {
    if (filters == null) return services;

    var filtered = services;

    // Apply price filter
    if (filters.minPrice != null || filters.maxPrice != null) {
      filtered = filtered.where((service) {
        final price = service.offerPrice ?? service.originalPrice;
        if (price == null) return true; // Include services without price
        
        if (filters.minPrice != null && price < filters.minPrice!) return false;
        if (filters.maxPrice != null && price > filters.maxPrice!) return false;
        
        return true;
      }).toList();
    }

    // Apply rating filter
    if (filters.minRating != null) {
      filtered = filtered.where((service) {
        final rating = service.rating;
        return rating != null && rating >= filters.minRating!;
      }).toList();
    }

    // Apply sorting
    if (filters.sortBy != null) {
      switch (filters.sortBy!) {
        case 'price_low':
          filtered.sort((a, b) => ((a.offerPrice ?? a.originalPrice) ?? 0).compareTo((b.offerPrice ?? b.originalPrice) ?? 0));
          break;
        case 'price_high':
          filtered.sort((a, b) => ((b.offerPrice ?? b.originalPrice) ?? 0).compareTo((a.offerPrice ?? a.originalPrice) ?? 0));
          break;
        case 'rating':
          filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
        case 'popularity':
          // For now, just sort by rating as a proxy for popularity
          filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
      }
    }

    return filtered;
  }

  /// Get offline cached search results
  Future<List<ServiceListingModel>> _getOfflineSearchResults(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('${_cacheKey}_$query');
      if (cachedJson != null) {
        final data = json.decode(cachedJson) as Map<String, dynamic>;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
        
        // Check if cache is still valid (1 hour)
        if (DateTime.now().difference(timestamp).inHours < 1) {
          final servicesJson = data['services'] as List<dynamic>;
          return servicesJson
              .map((jsonItem) => ServiceListingModel.fromJson(jsonItem as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      //('Failed to get offline search results: $e');
    }
    
    return <ServiceListingModel>[];
  }

  /// Save search results to offline cache
  Future<void> _saveOfflineSearchResults(String query, List<ServiceListingModel> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'services': results.map((service) => service.toJson()).toList(),
      };
      await prefs.setString('${_cacheKey}_$query', json.encode(data));
    } catch (e) {
      //('Failed to save offline search results: $e');
    }
  }

  /// Generate cache key for search
  String _generateCacheKey(String query, SearchFilterState? filters) {
    final filterKey = filters != null ? filters.toJson().toString() : '';
    return '$query-$filterKey';
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