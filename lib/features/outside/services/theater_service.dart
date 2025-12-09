import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import '../models/theater_screen_model.dart';

class TheaterService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Calculate final price user sees using Sylonow fees calculation
  /// Returns the total_price_user_sees from the RPC function
  Future<double> calculateFinalPrice(double basePrice, {double addonsPrice = 0.0}) async {
    try {
      // Fetch admin settings for calculation parameters
      final settings = await _supabase
          .from('admin_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', ['percent_tax', 'commission_percent', 'commission_gst', 'advance_factor']);

      // Extract values from settings
      double percentTax = 18.0;
      double commissionPercent = 10.0;
      double commissionGst = 18.0;
      double advanceFactor = 70.0;

      for (final setting in settings) {
        final key = setting['setting_key'] as String;
        final value = (setting['setting_value'] as num).toDouble();

        switch (key) {
          case 'percent_tax':
            percentTax = value;
            break;
          case 'commission_percent':
            commissionPercent = value;
            break;
          case 'commission_gst':
            commissionGst = value;
            break;
          case 'advance_factor':
            advanceFactor = value;
            break;
        }
      }

      // Call RPC function
      final result = await _supabase.rpc('calc_sylonow_fees', params: {
        'service_base': basePrice,
        'addons_base': addonsPrice,
        'percent_tax': percentTax,
        'commission_percent': commissionPercent,
        'commission_gst': commissionGst,
        'advance_factor': advanceFactor,
      });

      final totalPriceUserSees = (result['total_price_user_sees'] as num).toDouble();
      return PriceRounding.applyFinalRounding(totalPriceUserSees);
    } catch (e) {
      print('Error calculating final price: $e');
      // Fallback: return base price with manual tax calculation
      return PriceRounding.applyFinalRounding(basePrice + (basePrice * 0.18) + 19);
    }
  }

  /// Fetches theater screens with location-based filtering and distance calculation
  Future<List<TheaterScreen>> fetchTheaterScreensWithLocation({
    double? userLat,
    double? userLon,
    double radiusKm = 60.0, // Default 60km radius
  }) async {
    try {
      // If user location is provided, use RPC function for distance-based filtering
      if (userLat != null && userLon != null) {
        final response = await _supabase.rpc(
          'get_theater_screens_with_distance',
          params: {
            'user_lat': userLat,
            'user_lon': userLon,
            'radius_km': radiusKm,
          },
        );

        if (response == null) return [];

        final screens = <TheaterScreen>[];
        for (var screenData in response as List) {
          try {
            final screenDataMap = Map<String, dynamic>.from(screenData as Map<String, dynamic>);

            // Fetch pricing information from time slots
            final screenId = screenDataMap['id'] as String?;
            if (screenId != null) {
              final prices = await _fetchPricesForScreen(screenId);
              // Store final user price as the display price (what customer sees on cards)
              if (prices['finalUserPrice']! > 0) {
                screenDataMap['base_price'] = prices['finalUserPrice'];
                screenDataMap['hourly_rate'] = prices['finalUserPrice'];
              }
              if (prices['maxComparePrice']! > 0) {
                screenDataMap['compare_price'] = prices['maxComparePrice'];
              }
              // Store original base price and vendor payout for backend calculations
              if (prices['minBasePrice']! > 0) {
                screenDataMap['original_base_price'] = prices['minBasePrice'];
              }
              if (prices['vendorPayout']! > 0) {
                screenDataMap['vendor_payout'] = prices['vendorPayout'];
              }
            }

            final screen = TheaterScreen.fromJson(screenDataMap);
            screens.add(screen);
          } catch (parseError) {
            // Continue processing other screens
          }
        }
        return screens;
      }

      // Fallback to original method if no location provided
      return await fetchTheaterScreensWithPricing();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch minimum base_price and maximum compare_price for a specific theater screen from time slots
  /// Also calculates the final user price and vendor payout using the calc_sylonow_fees RPC function
  Future<Map<String, double>> _fetchPricesForScreen(String screenId) async {
    try {
      final response = await _supabase
          .from('theater_time_slots')
          .select('base_price, compare_price')
          .eq('screen_id', screenId)
          .eq('is_active', true);

      if (response.isEmpty) return {'minBasePrice': 0.0, 'maxComparePrice': 0.0, 'finalUserPrice': 0.0, 'vendorPayout': 0.0};

      double minBasePrice = double.infinity;
      double maxComparePrice = 0.0;

      for (final slot in response) {
        final basePrice = (slot['base_price'] as num?)?.toDouble();
        final comparePrice = (slot['compare_price'] as num?)?.toDouble();

        // Track minimum base price
        if (basePrice != null && basePrice > 0 && basePrice < minBasePrice) {
          minBasePrice = basePrice;
        }

        // Track maximum compare price
        if (comparePrice != null && comparePrice > maxComparePrice) {
          maxComparePrice = comparePrice;
        }
      }

      final finalMinBasePrice = minBasePrice == double.infinity ? 0.0 : minBasePrice;

      // Calculate prices using RPC function
      double finalUserPrice = 0.0;
      double vendorPayout = 0.0;
      if (finalMinBasePrice > 0) {
        try {
          // Fetch admin settings
          final settings = await _supabase
              .from('admin_settings')
              .select('setting_key, setting_value')
              .inFilter('setting_key', ['percent_tax', 'commission_percent', 'commission_gst', 'advance_factor']);

          double commissionPercent = 10.0;
          double commissionGst = 18.0;

          for (final setting in settings) {
            final key = setting['setting_key'] as String;
            final value = (setting['setting_value'] as num).toDouble();

            switch (key) {
              case 'commission_percent':
                commissionPercent = value;
                break;
              case 'commission_gst':
                commissionGst = value;
                break;
            }
          }

          // Calculate vendor payout (what customer sees on cards as "from" price)
          // vendor_payout = base_price - total_commission
          final commission = finalMinBasePrice * (commissionPercent / 100);
          final totalCommission = commission * (1 + commissionGst / 100);
          vendorPayout = finalMinBasePrice - totalCommission;

          // Also calculate final user price for checkout
          finalUserPrice = await calculateFinalPrice(finalMinBasePrice);
        } catch (e) {
          print('Error calculating vendor payout: $e');
          vendorPayout = finalMinBasePrice; // Fallback to base price
        }
      }

      return {
        'minBasePrice': finalMinBasePrice > 0 ? PriceRounding.applyFinalRounding(finalMinBasePrice) : 0.0,
        'maxComparePrice': maxComparePrice > 0 ? PriceRounding.applyFinalRounding(maxComparePrice) : 0.0,
        'finalUserPrice': finalUserPrice,
        'vendorPayout': vendorPayout > 0 ? PriceRounding.applyFinalRounding(vendorPayout) : 0.0,
      };
    } catch (e) {
      return {'minBasePrice': 0.0, 'maxComparePrice': 0.0, 'finalUserPrice': 0.0, 'vendorPayout': 0.0};
    }
  }

  /// Fetches theater screens with optimized pricing from time slots (legacy method)
  /// Only returns screens that have active time slots (!inner join ensures this)
  Future<List<TheaterScreen>> fetchTheaterScreensWithPricing() async {
    try {
      // Use more efficient query with specific column selection and join private_theaters for theater name
      // !inner join on theater_time_slots ensures only screens WITH time slots are returned
      final response = await _supabase
          .from('theater_screens')
          .select('''
            id,
            theater_id,
            screen_name,
            screen_number,
            capacity,
            amenities,
            hourly_rate,
            is_active,
            created_at,
            updated_at,
            total_capacity,
            allowed_capacity,
            charges_extra_per_person,
            video_url,
            images,
            description,
            time_slots,
            what_included,
            category_id,
            private_theaters!inner(name, approval_status),
            theater_time_slots!inner(
              base_price,
              compare_price,
              is_active
            )
          ''')
          .eq('is_active', true)
          .eq('private_theaters.approval_status', 'approved')
          .eq('private_theaters.is_verified', true)
          .eq('theater_time_slots.is_active', true)
          .order('screen_name', ascending: true);

      final screens = <TheaterScreen>[];

      for (int i = 0; i < response.length; i++) {
        try {
          final screenData = Map<String, dynamic>.from(response[i]);

          // Extract and process minimum pricing
          final minPrice = _calculateMinimumPrice(screenData);

          // Extract theater name from private_theaters join
          final theaters = screenData['private_theaters'];
          if (theaters != null && theaters is Map) {
            final theaterName = theaters['name'] as String?;
            if (theaterName != null) {
              screenData['theater_name'] = theaterName;
            }
          }

          // Clean up data structure
          screenData.remove('theater_time_slots');
          screenData['hourly_rate'] = minPrice;

          final screen = TheaterScreen.fromJson(screenData);
          screens.add(screen);
        } catch (parseError) {
          // Continue processing other screens instead of failing completely
        }
      }

      return screens;
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate minimum base_price and maximum compare_price from time slots
  /// Sets both base_price and compare_price in screenData
  double _calculateMinimumPrice(Map<String, dynamic> screenData) {
    final timeSlots = screenData['theater_time_slots'] as List? ?? [];
    double minBasePrice = double.infinity;
    double maxComparePrice = 0.0;

    for (final slot in timeSlots) {
      final basePrice = (slot['base_price'] as num?)?.toDouble();
      final comparePrice = (slot['compare_price'] as num?)?.toDouble();

      // Track minimum base price
      if (basePrice != null && basePrice > 0 && basePrice < minBasePrice) {
        minBasePrice = basePrice;
      }

      // Track maximum compare price
      if (comparePrice != null && comparePrice > maxComparePrice) {
        maxComparePrice = comparePrice;
      }
    }

    // Fallback to original hourly_rate if no valid time slot prices found
    if (minBasePrice == double.infinity) {
      minBasePrice = (screenData['hourly_rate'] as num?)?.toDouble() ?? 0.0;
    }

    // Set base_price in screenData if we found one
    if (minBasePrice > 0) {
      screenData['base_price'] = PriceRounding.applyFinalRounding(minBasePrice);
    }

    // Set compare_price in screenData if we found one
    if (maxComparePrice > 0) {
      screenData['compare_price'] = PriceRounding.applyFinalRounding(maxComparePrice);
    }

    // Apply price rounding before returning
    return minBasePrice > 0 ? PriceRounding.applyFinalRounding(minBasePrice) : 0.0;
  }

  /// Fetch theater screens by IDs (for caching optimization)
  /// Only returns screens that have active time slots (!inner join ensures this)
  Future<List<TheaterScreen>> fetchTheaterScreensByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      // !inner join on theater_time_slots ensures only screens WITH time slots are returned
      final response = await _supabase
          .from('theater_screens')
          .select('''
            *,
            private_theaters!inner(name, approval_status),
            theater_time_slots!inner(
              base_price,
              compare_price,
              is_active
            )
          ''')
          .inFilter('id', ids)
          .eq('is_active', true)
          .eq('private_theaters.approval_status', 'approved')
          .eq('private_theaters.is_verified', true)
          .eq('theater_time_slots.is_active', true);

      return response.map((data) {
        final screenData = Map<String, dynamic>.from(data);
        final minPrice = _calculateMinimumPrice(screenData);

        // Extract theater name from private_theaters join
        final theaters = screenData['private_theaters'];
        if (theaters != null && theaters is Map) {
          final theaterName = theaters['name'] as String?;
          if (theaterName != null) {
            screenData['theater_name'] = theaterName;
          }
        }

        screenData.remove('theater_time_slots');
        screenData['hourly_rate'] = minPrice;
        return TheaterScreen.fromJson(screenData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Search theater screens with optimized query
  /// Only returns screens that have active time slots (!inner join ensures this)
  Future<List<TheaterScreen>> searchTheaterScreens(String query) async {
    if (query.trim().isEmpty) {
      return fetchTheaterScreensWithPricing();
    }

    try {
      // !inner join on theater_time_slots ensures only screens WITH time slots are returned
      final response = await _supabase
          .from('theater_screens')
          .select('''
            *,
            private_theaters!inner(name, approval_status),
            theater_time_slots!inner(
              base_price,
              compare_price,
              is_active
            )
          ''')
          .or('screen_name.ilike.%$query%,description.ilike.%$query%')
          .eq('is_active', true)
          .eq('private_theaters.approval_status', 'approved')
          .eq('private_theaters.is_verified', true)
          .eq('theater_time_slots.is_active', true)
          .limit(20); // Limit results for performance

      return response.map((data) {
        final screenData = Map<String, dynamic>.from(data);
        final minPrice = _calculateMinimumPrice(screenData);

        // Extract theater name from private_theaters join
        final theaters = screenData['private_theaters'];
        if (theaters != null && theaters is Map) {
          final theaterName = theaters['name'] as String?;
          if (theaterName != null) {
            screenData['theater_name'] = theaterName;
          }
        }

        screenData.remove('theater_time_slots');
        screenData['hourly_rate'] = minPrice;
        return TheaterScreen.fromJson(screenData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }
}