import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/features/home/models/quote_model.dart';
import 'package:sylonow_user/features/home/models/vendor_model.dart';
import 'package:sylonow_user/features/home/models/service_type_model.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/home/models/category_model.dart';

/// Repository class for handling home screen data operations
/// 
/// This class provides methods to fetch data for different sections
/// of the home screen from Supabase database
class HomeRepository {
  /// Supabase client instance
  final SupabaseClient _supabase;

  /// Creates a new HomeRepository instance
  const HomeRepository(this._supabase);

  /// Fetches a random daily quote from the quotes table
  /// 
  /// Returns a random motivational quote or null if not found
  Future<QuoteModel?> getDailyQuote() async {
    try {
      final response = await _supabase
          .rpc('get_random_quote');

      if (response != null) {
        return QuoteModel.fromJson(response);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch daily quote: $e');
    }
  }

  /// Fetches a vendor by ID
  /// 
  /// Returns a vendor model or null if not found
  Future<VendorModel?> getVendorById(String vendorId) async {
    try {
      //('🔍 HomeRepository: Fetching vendor with ID: $vendorId');
      final response = await _supabase
          .from('vendors') 
          .select()
          .eq('id', vendorId)
          .maybeSingle();

      if (response == null) {
        //('🔍 HomeRepository: No vendor found with ID: $vendorId');
        return null;
      }

      //('🔍 HomeRepository: Raw vendor response: $response');
      final vendor = VendorModel.fromJson(response);
      //('🔍 HomeRepository: Parsed vendor model: $vendor');
      return vendor;
    } catch (e, stackTrace) {
      //('❌ HomeRepository: Error fetching vendor $vendorId: $e');
      //('❌ HomeRepository: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Fetches featured partners/vendors
  /// 
  /// Returns a list of verified and active vendors
  /// Limited to [limit] number of vendors (default: 10)
  Future<List<VendorModel>> getFeaturedPartners({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('vendors')
          .select()
          .eq('is_active', true)
          .eq('is_verified', true)
          .order('rating', ascending: false)
          
          .order('total_jobs_completed', ascending: false)
          .limit(limit);

      return response
          .map<VendorModel>((data) => VendorModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch featured partners: $e');
    }
  }

  /// Fetches service categories/types
  /// 
  /// Returns a list of active service types
  /// Limited to [limit] number of categories (default: 8)
  Future<List<ServiceTypeModel>> getServiceCategories({int limit = 8}) async {
    try {
      final response = await _supabase
          .from('service_types')
          .select()
          .eq('is_active', true)
          .order('name')
          .limit(limit);

      return response
          .map<ServiceTypeModel>((data) => ServiceTypeModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch service categories: $e');
    }
  }

  /// Fetches featured services
  /// 
  /// Returns a list of featured and active service listings from verified and active vendors
  /// Limited to [limit] number of services (default: 10)
  Future<List<ServiceListingModel>> getFeaturedServices(
      {int limit = 10, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified,
              is_active
            )
          ''')
          .eq('is_featured', true)
          .eq('is_active', true)
          .eq('is_verified', true)
          .eq('vendors.verification_status', 'verified')
          .limit(limit)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) {
        return [];
      }

      return response
          .map((item) => ServiceListingModel.fromJson(item))
          .toList();
    } catch (e) {
      // TODO: Add robust error handling, e.g., logging
      rethrow;
    }
  }

  /// Fetches private theater services
  /// 
  /// Returns a list of private theater related service listings from verified and active vendors
  /// Limited to [limit] number of services (default: 4)
  Future<List<ServiceListingModel>> getPrivateTheaterServices({int limit = 4}) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified,
              is_active
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true)
          .eq('vendors.verification_status', 'verified')
          .ilike('category', '%theater%')
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch private theater services: $e');
    }
  }

  /// Fetches popular nearby services within a radius
  ///
  /// Returns a list of popular services within the specified radius from user's location
  /// Uses Haversine formula to calculate distance between coordinates
  /// [userLat] User's latitude coordinate
  /// [userLon] User's longitude coordinate
  /// [radiusKm] Search radius in kilometers (default: 20km)
  /// Limited to [limit] number of services (default: 6)
  Future<List<ServiceListingModel>> getPopularNearbyServices({
    int limit = 6,
    double? userLat,
    double? userLon,
    double radiusKm = 20.0,
  }) async {
    try {
      // If no coordinates provided, return all services (fallback)
      if (userLat == null || userLon == null) {
        //('🔍 No coordinates provided, returning all services');
        final response = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors!inner(
                rating,
                total_reviews,
                total_jobs_completed,
                is_verified,
                is_active
              )
            ''')
            .eq('is_active', true)
            .eq('is_verified', true)
            .order('created_at', ascending: false)
            .limit(limit);

        return response
            .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
            .toList();
      }

      debugPrint('🔍 Fetching services within ${radiusKm}km of ($userLat, $userLon) using RPC');

      // Use RPC function for efficient distance-based filtering (like theater screens)
      final response = await _supabase.rpc(
        'get_nearby_services_with_price',
        params: {
          'user_lat': userLat,
          'user_lon': userLon,
          'radius_km': radiusKm,
          'service_limit': limit,
        },
      );

      if (response == null || response.isEmpty) {
        debugPrint('📦 No services found within ${radiusKm}km');
        return [];
      }

      debugPrint('📦 Fetched ${response.length} services from RPC');

      final services = <ServiceListingModel>[];
      for (var serviceData in response) {
        try {
          final serviceDataMap = Map<String, dynamic>.from(serviceData as Map);

          // The RPC already returns calculated_price and distance_km
          debugPrint('✅ Service: ${serviceDataMap['title']}, Distance: ${serviceDataMap['distance_km']} km, Price: ${serviceDataMap['calculated_price']}');

          services.add(ServiceListingModel.fromJson(serviceDataMap));
        } catch (e) {
          debugPrint('⚠️ Error parsing service: $e');
          continue;
        }
      }

      debugPrint('📊 Returning ${services.length} services');
      return services;
    } catch (e) {
      //('❌ Error fetching nearby services: $e');
      // Fallback: return all services if RPC fails
      try {
        final response = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors!inner(
                rating,
                total_reviews,
                total_jobs_completed,
                is_verified,
                is_active
              )
            ''')
            .eq('is_active', true)
            .eq('is_verified', true)
            .eq('vendors.verification_status', 'verified')
            .order('created_at', ascending: false)
            .limit(limit);

        return response
            .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
            .toList();
      } catch (fallbackError) {
        throw Exception('Failed to fetch nearby services: $fallbackError');
      }
    }
  }

  /// Fetches a specific service by ID
  /// 
  /// Returns the service details if found, with flexible conditions for debugging
  Future<ServiceListingModel?> getServiceById(String serviceId) async {
    try {
      //('🔍 Searching for service with ID: $serviceId');
      
      // First try with all conditions
      try {
        final strictResponse = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors!inner(
                id,
                business_name,
                full_name,
                rating,
                total_reviews,
                total_jobs_completed,
                profile_image_url,
                location,
                is_verified,
                is_online
              )
            ''')
            .eq('id', serviceId)
            .eq('is_active', true)
            .eq('is_verified', true)
            .eq('vendors.verification_status', 'verified')
            .eq('vendors.is_online', true)
            .single();

        //('✅ Service found with strict conditions');
        return ServiceListingModel.fromJson(strictResponse);
      } catch (strictError) {
        //('❌ Service not found with strict conditions: $strictError');
      }

      // If strict conditions fail, try with relaxed conditions for debugging
      try {
        final relaxedResponse = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors(
                id,
                business_name,
                full_name,
                rating,
                total_reviews,
                total_jobs_completed,
                profile_image_url,
                location,
                is_verified,
                is_online
              )
            ''')
            .eq('id', serviceId)
            .maybeSingle();

        if (relaxedResponse == null) {
          //('❌ Service not found with ID: $serviceId');
          return null;
        }

        //('📋 Service found with relaxed conditions:');
        //('  - Service active: ${relaxedResponse['is_active']}');
        //('  - Service verified: ${relaxedResponse['is_verified']}');
        
        final vendorData = relaxedResponse['vendors'];
        if (vendorData != null) {
          //('  - Vendor accessible: true');
          //('  - Vendor online: ${vendorData['is_online']}');
          //('  - Vendor verified: ${vendorData['is_verified']}');
        } else {
          //('  - Vendor accessible: false (due to RLS policy)');
          //('  - Service will be shown but booking may be disabled');
        }

        // Return the service even with relaxed conditions
        return ServiceListingModel.fromJson(relaxedResponse);
      } catch (relaxedError) {
        //('❌ Service not found even with relaxed conditions: $relaxedError');
      }

      return null;
    } catch (e) {
      //('❌ Error in getServiceById: $e');
      return null;
    }
  }

  /// Fetches related services by category
  /// 
  /// Returns a list of services in the same category, excluding the current service
  /// If no services found in same category, returns other services
  Future<List<ServiceListingModel>> getRelatedServices({
    required String currentServiceId,
    String? category,
    int limit = 4,
  }) async {
    try {
      List<ServiceListingModel> results = [];

      // First, try to get services in the same category
      if (category != null && category.isNotEmpty) {
        final categoryResponse = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors(
                id,
                business_name,
                full_name,
                rating,
                total_reviews
              )
            ''')
            .eq('is_active', true)
            .eq('is_verified', true)
            .eq('category', category)
            .neq('id', currentServiceId)
            .not('cover_photo', 'is', null)
            .limit(limit)
            .order('rating', ascending: false);

        results = categoryResponse
            .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
            .toList();
      }

      // If no services found in same category, get any other services
      if (results.isEmpty) {
        final generalResponse = await _supabase
            .from('service_listings')
            .select('''
              *,
              vendors(
                id,
                business_name,
                full_name,
                rating,
                total_reviews
              )
            ''')
            .eq('is_active', true)
            .eq('is_verified', true)
            .neq('id', currentServiceId)
            .not('cover_photo', 'is', null)
            .limit(limit)
            .order('rating', ascending: false);

        results = generalResponse
            .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
            .toList();
      }

      return results;
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Fetches all categories
  /// 
  /// Returns a list of active categories sorted by sort_order
  Future<List<CategoryModel>> getCategories({int? limit}) async {
    try {
      var query = _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return response
          .map<CategoryModel>((data) => CategoryModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Fetches services by category
  /// 
  /// Returns a list of services filtered by category from verified and active vendors
  Future<List<ServiceListingModel>> getServicesByCategory({
    required String categoryName,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified,
              is_active
            )
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .eq('vendor.is_verified', true)
          .eq('vendor.is_active', true)
          .limit(limit)
          .range(offset, offset + limit - 1)
          .order('rating', ascending: false);

      return response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services by category: $e');
    }
  }

  /// Fetches services by decoration type
  /// 
  /// Returns a list of services filtered by decoration type ('inside', 'outside', or 'both') from verified and active vendors
  /// Used to differentiate between inside and outside decoration services
  Future<List<ServiceListingModel>> getServicesByDecorationType({
    required String decorationType,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified,
              is_active
            )
          ''')
          .eq('is_active', true)
          .eq('vendor.is_verified', true)
          .eq('vendor.is_active', true)
          .or('decoration_type.eq.$decorationType,decoration_type.eq.both')
          .limit(limit)
          .range(offset, offset + limit - 1)
          .order('rating', ascending: false);

      final results = <ServiceListingModel>[];
      for (int i = 0; i < response.length; i++) {
        try {
          final data = response[i];
          final service = ServiceListingModel.fromJson(data);
          results.add(service);
        } catch (e) {
          // Skip this record and continue with others
          continue;
        }
      }
      
      return results;
    } catch (e) {
      throw Exception('Failed to fetch services by decoration type: $e');
    }
  }

  /// Fetches featured services by decoration type
  /// 
  /// Returns a list of featured services filtered by decoration type
  Future<List<ServiceListingModel>> getFeaturedServicesByDecorationType({
    required String decorationType,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendors(
              id,
              business_name,
              full_name,
              rating,
              total_reviews
            )
          ''')
          .eq('is_featured', true)
          .eq('is_active', true)
          .eq('is_verified', true)
          .or('decoration_type.eq.$decorationType,decoration_type.eq.both')
          .limit(limit)
          .range(offset, offset + limit - 1)
          .order('rating', ascending: false);

      return response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch featured services by decoration type: $e');
    }
  }

  /// Fetches popular nearby services by decoration type
  /// 
  /// Returns a list of popular services filtered by decoration type
  Future<List<ServiceListingModel>> getPopularNearbyServicesByDecorationType({
    required String decorationType,
    int limit = 6,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendors!inner(
              rating,
              total_reviews,
              total_jobs_completed
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true)
          .or('decoration_type.eq.$decorationType,decoration_type.eq.both')
          .order('vendors.rating', ascending: false)
          .order('vendors.total_reviews', ascending: false)
          .limit(limit);

      return response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch popular nearby services by decoration type: $e');
    }
  }

  /// Fetches all home screen data at once
  /// 
  /// Returns a map containing all the home screen data
  /// This is useful for loading all sections simultaneously
  Future<Map<String, dynamic>> getHomeScreenData() async {
    try {
      final results = await Future.wait([
        getDailyQuote(),
        getFeaturedPartners(),
        getServiceCategories(),
        getFeaturedServices(),
        getPrivateTheaterServices(),
        getPopularNearbyServices(),
        getCategories(limit: 8), // Add categories to home screen data
      ]);

      return {
        'dailyQuote': results[0] as QuoteModel?,
        'featuredPartners': results[1],
        'serviceCategories': results[2],
        'featuredServices': results[3],
        'privateTheaterServices': results[4],
        'popularNearbyServices': results[5],
        'categories': results[6],
      };
    } catch (e) {
      throw Exception('Failed to fetch home screen data: $e');
    }
  }

  /// Fetches home screen data filtered by decoration type
  /// 
  /// Returns a map containing home screen data filtered for specific decoration type
  Future<Map<String, dynamic>> getHomeScreenDataByDecorationType(String decorationType) async {
    try {
      final results = await Future.wait([
        getDailyQuote(),
        getFeaturedPartners(),
        getServiceCategories(),
        getFeaturedServicesByDecorationType(decorationType: decorationType),
        getPrivateTheaterServices(),
        getPopularNearbyServicesByDecorationType(decorationType: decorationType),
        getCategories(limit: 8),
      ]);

      return {
        'dailyQuote': results[0] as QuoteModel?,
        'featuredPartners': results[1],
        'serviceCategories': results[2],
        'featuredServices': results[3],
        'privateTheaterServices': results[4],
        'popularNearbyServices': results[5],
        'categories': results[6],
      };
    } catch (e) {
      throw Exception('Failed to fetch home screen data by decoration type: $e');
    }
  }

  /// Apply location-based calculations to a list of services
  /// 
  /// Calculates distance from user location and adjusts prices for services > 10km away
  List<ServiceListingModel> _applyLocationCalculations({
    required List<ServiceListingModel> services,
    required double? userLat,
    required double? userLon,
    bool sortByDistance = false,
    double? radiusFilter,
  }) {
    if (userLat == null || userLon == null) {
      return services;
    }

    // Apply location calculations to each service
    List<ServiceListingModel> processedServices = services
        .where((service) => service.latitude != null && service.longitude != null)
        .map((service) => service.copyWithLocationData(
              userLat: userLat,
              userLon: userLon,
            ))
        .toList();

    // Filter by radius if specified
    if (radiusFilter != null) {
      processedServices = processedServices
          .where((service) => service.distanceKm != null && service.distanceKm! <= radiusFilter)
          .toList();
    }

    // Sort by distance if requested
    if (sortByDistance) {
      processedServices.sort((a, b) => 
          (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    }

    return processedServices;
  }

  /// Fetches services with location-based filtering and pricing
  /// 
  /// Returns services sorted by distance with location-based price adjustments
  Future<List<ServiceListingModel>> getServicesWithLocation({
    required double userLat,
    required double userLon,
    String? decorationType,
    String? category,
    double? radiusKm,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendors(
              id,
              business_name,
              full_name,
              rating,
              total_reviews
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true);

      // Apply decoration type filter
      if (decorationType != null) {
        query = query.or('decoration_type.eq.$decorationType,decoration_type.eq.both');
      }

      // Apply category filter
      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query
          .limit(limit)
          .range(offset, offset + limit - 1);

      final services = response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();

      // Apply location calculations
      return _applyLocationCalculations(
        services: services,
        userLat: userLat,
        userLon: userLon,
        sortByDistance: true,
        radiusFilter: radiusKm,
      );
    } catch (e) {
      throw Exception('Failed to fetch services with location: $e');
    }
  }

  /// Fetches services by decoration type with location calculations
  /// 
  /// Enhanced version of getServicesByDecorationType with location features
  Future<List<ServiceListingModel>> getServicesByDecorationTypeWithLocation({
    required String decorationType,
    required double userLat,
    required double userLon,
    double? radiusKm,
    int limit = 10,
    int offset = 0,
  }) async {
    return getServicesWithLocation(
      userLat: userLat,
      userLon: userLon,
      decorationType: decorationType,
      radiusKm: radiusKm,
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches featured services with location calculations
  /// 
  /// Enhanced version of getFeaturedServices with location features
  Future<List<ServiceListingModel>> getFeaturedServicesWithLocation({
    required double userLat,
    required double userLon,
    String? decorationType,
    double? radiusKm,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendors(
              id,
              business_name,
              full_name,
              rating,
              total_reviews
            )
          ''')
          .eq('is_featured', true)
          .eq('is_active', true)
          .eq('is_verified', true);

      // Apply decoration type filter
      if (decorationType != null) {
        query = query.or('decoration_type.eq.$decorationType,decoration_type.eq.both');
      }

      final response = await query
          .limit(limit)
          .range(offset, offset + limit - 1);

      final services = response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();

      // Apply location calculations
      return _applyLocationCalculations(
        services: services,
        userLat: userLat,
        userLon: userLon,
        sortByDistance: true,
        radiusFilter: radiusKm,
      );
    } catch (e) {
      throw Exception('Failed to fetch featured services with location: $e');
    }
  }

  /// Fetches popular nearby services with enhanced location calculations
  /// 
  /// Enhanced version that actually considers user location for "nearby"
  Future<List<ServiceListingModel>> getPopularNearbyServicesWithLocation({
    required double userLat,
    required double userLon,
    String? decorationType,
    double radiusKm = 25.0, // Default 25km radius for "nearby"
    int limit = 6,
  }) async {
    try {
      var query = _supabase
          .from('service_listings')
          .select('''
            *,
            vendors(
              rating,
              total_reviews,
              total_jobs_completed
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true)
          .not('cover_photo', 'is', null);

      // Apply decoration type filter
      if (decorationType != null) {
        query = query.or('decoration_type.eq.$decorationType,decoration_type.eq.both');
      }

      final response = await query
          .order('created_at', ascending: false) // Order by creation date since vendor data might be empty
          .limit(limit * 3); // Fetch more to have options after radius filtering

      final services = response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();

      // Apply location calculations with radius filter
      final locationFilteredServices = _applyLocationCalculations(
        services: services,
        userLat: userLat,
        userLon: userLon,
        sortByDistance: true,
        radiusFilter: radiusKm,
      );

      // Return only the requested limit
      final result = locationFilteredServices.take(limit).toList();
      return result;
    } catch (e) {
      throw Exception('Failed to fetch popular nearby services with location: $e');
    }
  }

  /// Fetches services by category and decoration type
  /// 
  /// Returns a list of services filtered by both category and decoration type
  /// Optimized with database indexing and caching considerations
  Future<List<ServiceListingModel>> getServicesByCategoryAndDecorationType({
    required String categoryName,
    required String decorationType,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            id,
            title,
            description,
            category,
            decoration_type,
            cover_photo,
            original_price,
            offer_price,
            promotional_tag,
            rating,
            reviews_count,
            is_featured,
            latitude,
            longitude,
            vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified
            )
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .eq('is_verified', true)
          .eq('vendors.verification_status', 'verified')
          .or('decoration_type.eq.$decorationType,decoration_type.eq.both')
          .limit(limit)
          .range(offset, offset + limit - 1)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services by category and decoration type: $e');
    }
  }

  /// Fetches services by category and decoration type with location calculations
  /// 
  /// Enhanced version that includes location-based distance and pricing
  /// Optimized for better performance and caching
  Future<List<ServiceListingModel>> getServicesByCategoryAndDecorationTypeWithLocation({
    required String categoryName,
    required String decorationType,
    required double userLat,
    required double userLon,
    double? radiusKm,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            id,
            title,
            description,
            category,
            decoration_type,
            cover_photo,
            original_price,
            offer_price,
            promotional_tag,
            rating,
            reviews_count,
            is_featured,
            latitude,
            longitude,
            vendors!inner(
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified
            )
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .eq('is_verified', true)
          .eq('vendors.verification_status', 'verified')
          .or('decoration_type.eq.$decorationType,decoration_type.eq.both')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(limit * 3) // Fetch more to have options after radius filtering
          .range(offset, offset + (limit * 3) - 1)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      final services = response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .toList();

      // Apply location calculations
      final locationFilteredServices = _applyLocationCalculations(
        services: services,
        userLat: userLat,
        userLon: userLon,
        sortByDistance: true,
        radiusFilter: radiusKm,
      );

      // Return only the requested limit
      final result = locationFilteredServices.take(limit).toList();
      return result;
    } catch (e) {
      throw Exception('Failed to fetch services by category and decoration type with location: $e');
    }
  }

  /// Fetches services with a specific discount percentage or more
  /// 
  /// Returns a list of active services that have discount of [minDiscountPercent] or more
  /// Limited to 50 services and ordered by discount percentage descending
  Future<List<ServiceListingModel>> getServicesWithDiscount(int minDiscountPercent) async {
    try {
      final response = await _supabase
          .from('service_listings')
          .select('''
            *,
            vendors (
              id,
              business_name,
              full_name,
              rating,
              total_reviews,
              is_verified
            )
          ''')
          .eq('is_active', true)
          .eq('is_verified', true)
          .not('original_price', 'is', null)
          .not('offer_price', 'is', null)
          .filter('offer_price', 'lt', 'original_price')
          .limit(50)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      final services = response
          .map<ServiceListingModel>((data) => ServiceListingModel.fromJson(data))
          .where((service) {
            // Calculate discount percentage
            if (service.originalPrice != null && 
                service.offerPrice != null && 
                service.originalPrice! > service.offerPrice!) {
              final discountPercent = ((service.originalPrice! - service.offerPrice!) / service.originalPrice! * 100);
              return discountPercent >= minDiscountPercent;
            }
            return false;
          })
          .toList();

      // Sort by discount percentage descending
      services.sort((a, b) {
        final discountA = ((a.originalPrice! - a.offerPrice!) / a.originalPrice! * 100);
        final discountB = ((b.originalPrice! - b.offerPrice!) / b.originalPrice! * 100);
        return discountB.compareTo(discountA);
      });

      return services;
    } catch (e) {
      throw Exception('Failed to fetch services with discount: $e');
    }
  }

  /// Fetches service addons for a specific vendor
  /// 
  /// Returns a list of service addons from the service_add_ons table
  Future<List<dynamic>> getServiceAddons(String vendorId) async {
    try {
      //('🔍 HomeRepository: Fetching addons for vendor ID: $vendorId');
      
      final response = await _supabase
          .from('service_add_ons')
          .select('*')
          .eq('vendor_id', vendorId)
          .eq('is_available', true)
          .order('sort_order', ascending: true);

      //('✅ HomeRepository: Found ${response.length} addons for vendor $vendorId');
      
      return response.map((json) {
        return {
          'id': json['id'],
          'name': json['name'],
          'description': json['description'],
          'price': json['discount_price'] ?? json['original_price'], // Use discount price if available
          'original_price': json['original_price'],
          'discount_price': json['discount_price'], // Include discount_price for character calculations
          'images': json['images'], // Keep original images array
          'image_url': json['images'] != null && (json['images'] as List).isNotEmpty 
              ? (json['images'] as List).first 
              : null,
          'is_customizable': json['is_customizable'],
          'customization_input_type': json['customization_input_type'],
        };
      }).toList();
    } catch (e) {
      //('❌ HomeRepository: Failed to fetch service addons: $e');
      throw Exception('Failed to fetch service addons: $e');
    }
  }

  /// Fetches existing bookings for a service on a specific date
  /// 
  /// Returns list of booked time slots in 'hh:mm a' format
  Future<List<String>> getExistingBookings(String serviceId, String date) async {
    try {
      //('🔍 HomeRepository: Fetching bookings for service $serviceId on $date');
      
      // Query for orders on the specific date
      // booking_date is a timestamp, so we need to filter by date range
      final startOfDay = '${date}T00:00:00Z';
      final endOfDay = '${date}T23:59:59Z';
      
      //('🔍 Querying orders from $startOfDay to $endOfDay');
      
      final response = await _supabase
          .from('orders')
          .select('booking_time, booking_date, status')
          .eq('service_listing_id', serviceId)
          .gte('booking_date', startOfDay)
          .lte('booking_date', endOfDay)
          .neq('status', 'cancelled') // Exclude cancelled bookings
          .neq('status', 'completed') // Exclude completed bookings
          .order('booking_time');

      //('🔍 Raw response: $response');
      
      if (response.isEmpty) {
        //('🔍 HomeRepository: No existing bookings found');
        return [];
      }

      final bookedTimes = <String>[];
      for (final booking in response) {
        //('🔍 Processing booking: $booking');
        final bookingTime = booking['booking_time'] as String?;
        final bookingDate = booking['booking_date'] as String?;
        final status = booking['status'] as String?;
        
        //('🔍 Booking details: time=$bookingTime, date=$bookingDate, status=$status');
        
        if (bookingTime != null) {
          // Convert time from HH:mm:ss or HH:mm format to hh:mm a format
          try {
            final timeParts = bookingTime.split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            
            final dateTime = DateTime(2000, 1, 1, hour, minute);
            final formattedTime = DateFormat('hh:mm a').format(dateTime);
            bookedTimes.add(formattedTime);
            
            //('🔍 Found booked time: $bookingTime -> $formattedTime');
          } catch (e) {
            //('❌ Error parsing booking time $bookingTime: $e');
          }
        }
      }

      //('🔍 HomeRepository: Found ${bookedTimes.length} booked time slots');
      return bookedTimes;
    } catch (e) {
      //('❌ HomeRepository: Failed to fetch existing bookings: $e');
      throw Exception('Failed to fetch existing bookings: $e');
    }
  }

  /// Fetches all service listings for a vendor to get their booking notice periods
  Future<List<ServiceListingModel>> getVendorServiceListings(String vendorId) async {
    try {
      //('🔍 HomeRepository: Fetching service listings for vendor $vendorId');
      
      final response = await _supabase
          .from('service_listings')
          .select()
          .eq('vendor_id', vendorId);

      final List<ServiceListingModel> services = [];
      for (final item in response) {
        try {
          services.add(ServiceListingModel.fromJson(item));
        } catch (e) {
          //('❌ Error parsing service listing: $e');
        }
      }

      //('🔍 Found ${services.length} service listings for vendor $vendorId');
      return services;
    } catch (e) {
      //('❌ HomeRepository: Failed to fetch vendor service listings: $e');
      throw Exception('Failed to fetch vendor service listings: $e');
    }
  }

  /// Fetches all active bookings for a vendor within a date range
  Future<List<Map<String, dynamic>>> getVendorBookings(String vendorId, DateTime startDate, DateTime endDate) async {
    try {
      //('🔍 HomeRepository: Fetching vendor bookings for $vendorId from ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');
      
      final startOfRange = DateFormat('yyyy-MM-dd').format(startDate);
      final endOfRange = DateFormat('yyyy-MM-dd').format(endDate);
      
      final response = await _supabase
          .from('orders')
          .select('booking_date, booking_time, status, service_listing_id')
          .eq('vendor_id', vendorId)
          .gte('booking_date', startOfRange)
          .lte('booking_date', endOfRange)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .order('booking_date');

      //('🔍 Found ${response.length} active vendor bookings');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      //('❌ HomeRepository: Failed to fetch vendor bookings: $e');
      throw Exception('Failed to fetch vendor bookings: $e');
    }
  }

  /// Calculates blocked dates for a vendor based on existing bookings and their notice periods
  Future<List<DateTime>> getVendorBlockedDates(String vendorId) async {
    try {
      //('🔍 HomeRepository: Calculating blocked dates for vendor $vendorId');
      
      // Get all service listings for this vendor to know their booking notice periods
      final vendorServices = await getVendorServiceListings(vendorId);
      
      // Create a map of service listing ID to booking notice hours
      final Map<String, int> serviceNoticeHours = {};
      for (final service in vendorServices) {
        serviceNoticeHours[service.id] = _parseBookingNoticeToHours(service.bookingNotice);
      }
      
      // Get all active bookings for this vendor for the next 30 days (buffer for calculation)
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));
      final vendorBookings = await getVendorBookings(vendorId, now, futureDate);
      
      final Set<DateTime> blockedDates = {};
      
      for (final booking in vendorBookings) {
        final bookingDateStr = booking['booking_date'] as String?;
        final serviceListingId = booking['service_listing_id'] as String?;
        
        if (bookingDateStr == null || serviceListingId == null) continue;
        
        try {
          final bookingDate = DateTime.parse(bookingDateStr);
          final noticeHours = serviceNoticeHours[serviceListingId] ?? 0;
          
          // Calculate the blocked period: from (booking date - notice period) to booking date
          final blockStartDate = bookingDate.subtract(Duration(hours: noticeHours));
          
          //('📅 Booking on ${DateFormat('dd/MM/yyyy').format(bookingDate)} blocks from ${DateFormat('dd/MM/yyyy HH:mm').format(blockStartDate)} to ${DateFormat('dd/MM/yyyy').format(bookingDate)}');
          
          // Add all dates in the blocked period
          DateTime current = DateTime(blockStartDate.year, blockStartDate.month, blockStartDate.day);
          final endDate = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
          
          while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
            blockedDates.add(current);
            current = current.add(const Duration(days: 1));
          }
          
        } catch (e) {
          //('❌ Error processing booking date: $e');
        }
      }
      
      //('🚫 Vendor $vendorId has ${blockedDates.length} blocked dates: ${blockedDates.map((d) => DateFormat('dd/MM').format(d)).join(', ')}');
      return blockedDates.toList()..sort();
      
    } catch (e) {
      //('❌ HomeRepository: Failed to calculate blocked dates: $e');
      throw Exception('Failed to calculate blocked dates: $e');
    }
  }

  /// Helper method to parse booking notice string to hours
  int _parseBookingNoticeToHours(String? bookingNotice) {
    if (bookingNotice == null || bookingNotice.isEmpty) {
      return 0;
    }

    final lowerCaseNotice = bookingNotice.toLowerCase().trim();
    final RegExp numberRegex = RegExp(r'(\d+(?:\.\d+)?)');
    final match = numberRegex.firstMatch(lowerCaseNotice);
    
    if (match == null) {
      return 0;
    }
    
    final double number = double.tryParse(match.group(1)!) ?? 0;
    
    if (lowerCaseNotice.contains('day')) {
      return (number * 24).round();
    } else if (lowerCaseNotice.contains('hour')) {
      return number.round();
    } else if (lowerCaseNotice.contains('week')) {
      return (number * 7 * 24).round();
    }
    
    // Default assumption: assume days and convert to hours
    return (number * 24).round();
  }
} 