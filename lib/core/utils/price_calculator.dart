import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';

/// Utility class for calculating service prices with taxes and fees using Supabase RPC
class PriceCalculator {
  // Tax and fee constants (kept for fallback calculations)
  static const double transactionFeeRate = 0.0354; // 3.54%
  static const double gstRate = 0.18; // 18% GST
  static const double convenienceFee = 19.00; // ₹19 convenience fee for service listings

  /// Calculate total price for SERVICE LISTINGS display (SYNC - for immediate UI display)
  /// This is a fallback for UI that needs immediate rendering
  static double calculateTotalPriceWithTaxes(double servicePrice) {
    // Local calculation for immediate UI display
    final transactionFee = servicePrice * transactionFeeRate;
    final totalAmount = servicePrice + convenienceFee + transactionFee;
    // Apply rounding to ensure prices end with 49 or 99
    return PriceRounding.applyFinalRounding(totalAmount);
  }

  /// Calculate total price for SERVICE LISTINGS display using RPC (includes ₹28 convenience fee)
  /// Uses: calculate_service_listing_price RPC function (ASYNC - for accurate server-side calculation)
  static Future<double> calculateTotalPriceWithTaxesRPC(double servicePrice) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_service_listing_price',
        params: {'p_service_price': servicePrice},
      );
      
      if (response != null) {
        final result = response as Map<String, dynamic>;
        return (result['total_amount'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error calculating service listing price via RPC: $e');
      // Fallback to local calculation
    }
    
    // Fallback calculation
    final transactionFee = servicePrice * transactionFeeRate;
    final totalAmount = servicePrice + convenienceFee + transactionFee;
    return double.parse(totalAmount.toStringAsFixed(2));
  }

  /// Calculate total price for SERVICE DETAIL/CHECKOUT (SYNC - for immediate UI display)
  /// This is a fallback for UI that needs immediate rendering
  static double calculateCheckoutTotalWithTaxes(
    double serviceDiscountedPrice, {
    bool vendorHasGst = false,
  }) {
    // Local calculation for immediate UI display
    final transactionFee = serviceDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? serviceDiscountedPrice * gstRate : 0.0;
    final totalAmount = serviceDiscountedPrice + transactionFee + gstAmount;
    // Apply rounding to ensure prices end with 49 or 99
    return PriceRounding.applyFinalRounding(totalAmount);
  }

  /// Calculate total price for SERVICE DETAIL/CHECKOUT using RPC (NO ₹28 convenience fee)
  /// Uses: calculate_service_detail_price RPC function (ASYNC - for accurate server-side calculation)
  static Future<double> calculateCheckoutTotalWithTaxesRPC(
    double serviceDiscountedPrice, {
    bool vendorHasGst = false,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_service_detail_price',
        params: {
          'p_service_price': serviceDiscountedPrice,
          'p_vendor_has_gst': vendorHasGst,
        },
      );
      
      if (response != null) {
        final result = response as Map<String, dynamic>;
        return (result['total_amount'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error calculating service detail price via RPC: $e');
      // Fallback to local calculation
    }
    
    // Fallback calculation
    final transactionFee = serviceDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? serviceDiscountedPrice * gstRate : 0.0;
    final totalAmount = serviceDiscountedPrice + transactionFee + gstAmount;
    return double.parse(totalAmount.toStringAsFixed(2));
  }

  /// Get breakdown of price components for SERVICE DETAIL/CHECKOUT (SYNC - for immediate UI display)
  /// This is a fallback for UI that needs immediate rendering
  static Map<String, double> getCheckoutPriceBreakdown(
    double serviceDiscountedPrice, {
    bool vendorHasGst = false,
  }) {
    // Local calculation for immediate UI display
    final transactionFee = serviceDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? serviceDiscountedPrice * gstRate : 0.0;
    final totalAmount = serviceDiscountedPrice + transactionFee + gstAmount;

    final breakdown = {
      'servicePrice': serviceDiscountedPrice,
      'transactionFee': double.parse(transactionFee.toStringAsFixed(2)),
      'totalAmount': double.parse(totalAmount.toStringAsFixed(2)),
    };

    if (vendorHasGst) {
      breakdown['gst'] = double.parse(gstAmount.toStringAsFixed(2));
    }

    return breakdown;
  }

  /// Get breakdown of price components for SERVICE DETAIL/CHECKOUT using RPC
  /// Uses: calculate_service_detail_price RPC function (ASYNC - for accurate server-side calculation)
  static Future<Map<String, double>> getCheckoutPriceBreakdownRPC(
    double serviceDiscountedPrice, {
    bool vendorHasGst = false,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_service_detail_price',
        params: {
          'p_service_price': serviceDiscountedPrice,
          'p_vendor_has_gst': vendorHasGst,
        },
      );
      
      if (response != null) {
        final result = response as Map<String, dynamic>;
        final breakdown = {
          'servicePrice': (result['service_price'] as num).toDouble(),
          'transactionFee': (result['transaction_fee'] as num).toDouble(),
          'totalAmount': (result['total_amount'] as num).toDouble(),
        };
        
        // Add GST to breakdown if vendor has GST
        if (vendorHasGst && result['gst_amount'] != null) {
          breakdown['gst'] = (result['gst_amount'] as num).toDouble();
        }
        
        return breakdown;
      }
    } catch (e) {
      print('Error getting price breakdown via RPC: $e');
      // Fallback to local calculation
    }
    
    // Fallback calculation
    final transactionFee = serviceDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? serviceDiscountedPrice * gstRate : 0.0;
    final totalAmount = serviceDiscountedPrice + transactionFee + gstAmount;

    final breakdown = {
      'servicePrice': serviceDiscountedPrice,
      'transactionFee': double.parse(transactionFee.toStringAsFixed(2)),
      'totalAmount': double.parse(totalAmount.toStringAsFixed(2)),
    };

    if (vendorHasGst) {
      breakdown['gst'] = double.parse(gstAmount.toStringAsFixed(2));
    }

    return breakdown;
  }

  /// Format price with currency symbol
  static String formatPrice(double price) {
    return '₹${price.toStringAsFixed(2)}';
  }

  /// Format price as integer if no decimal places needed
  static String formatPriceAsInt(double price) {
    // Always display as integer (whole number) since our rounding ensures clean values
    return '₹${price.round()}';
  }

  /// Calculate taxes for a given amount (18% GST)
  static double calculateTaxes(double amount) {
    return amount * gstRate;
  }

  /// Calculate advance payment (typically 50% of total)
  static double calculateAdvancePayment(double totalAmount) {
    return totalAmount * 0.5; // 50% advance
  }

  // THEATER PRICING METHODS

  /// Calculate total price for THEATER LISTINGS display (SYNC - for immediate UI display)
  /// This includes ₹28 convenience fee + transaction fee for theater bookings
  static double calculateTheaterListingPriceWithTaxes(double theaterPrice) {
    // Local calculation for immediate UI display
    final transactionFee = theaterPrice * transactionFeeRate;
    final totalAmount = theaterPrice + convenienceFee + transactionFee;
    // Apply rounding to ensure prices end with 49 or 99
    return PriceRounding.applyFinalRounding(totalAmount);
  }

  /// Calculate total price for THEATER LISTINGS display using RPC (ASYNC - for accurate server-side calculation)
  /// Uses: calculate_theater_listing_price RPC function (includes ₹28 convenience fee)
  static Future<double> calculateTheaterListingPriceWithTaxesRPC(double theaterPrice) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_theater_listing_price',
        params: {'p_theater_price': theaterPrice},
      );

      if (response != null) {
        final result = response as Map<String, dynamic>;
        return (result['total_amount'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error calculating theater listing price via RPC: $e');
      // Fallback to local calculation
    }

    // Fallback calculation
    final transactionFee = theaterPrice * transactionFeeRate;
    final totalAmount = theaterPrice + convenienceFee + transactionFee;
    return double.parse(totalAmount.toStringAsFixed(2));
  }

  /// Calculate total price for THEATER DETAIL/CHECKOUT (SYNC - for immediate UI display)
  /// This is a fallback for UI that needs immediate rendering (NO ₹28 convenience fee)
  static double calculateTheaterCheckoutTotalWithTaxes(
    double theaterDiscountedPrice, {
    bool vendorHasGst = false,
  }) {
    // Local calculation for immediate UI display
    final transactionFee = theaterDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? theaterDiscountedPrice * gstRate : 0.0;
    final totalAmount = theaterDiscountedPrice + transactionFee + gstAmount;
    // Apply rounding to ensure prices end with 49 or 99
    return PriceRounding.applyFinalRounding(totalAmount);
  }

  /// Calculate total price for THEATER DETAIL/CHECKOUT using RPC (ASYNC - for accurate server-side calculation)
  /// Uses: calculate_theater_detail_price RPC function (NO ₹28 convenience fee)
  static Future<double> calculateTheaterCheckoutTotalWithTaxesRPC(
    double theaterDiscountedPrice, {
    bool vendorHasGst = false,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_theater_detail_price',
        params: {
          'p_theater_price': theaterDiscountedPrice,
          'p_vendor_has_gst': vendorHasGst,
        },
      );

      if (response != null) {
        final result = response as Map<String, dynamic>;
        return (result['total_amount'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error calculating theater detail price via RPC: $e');
      // Fallback to local calculation
    }

    // Fallback calculation
    final transactionFee = theaterDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? theaterDiscountedPrice * gstRate : 0.0;
    final totalAmount = theaterDiscountedPrice + transactionFee + gstAmount;
    return double.parse(totalAmount.toStringAsFixed(2));
  }

  /// Get breakdown of price components for THEATER DETAIL/CHECKOUT (SYNC - for immediate UI display)
  /// This is a fallback for UI that needs immediate rendering
  static Map<String, double> getTheaterCheckoutPriceBreakdown(
    double theaterDiscountedPrice, {
    bool vendorHasGst = false,
  }) {
    // Local calculation for immediate UI display
    final transactionFee = theaterDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? theaterDiscountedPrice * gstRate : 0.0;
    final totalAmount = theaterDiscountedPrice + transactionFee + gstAmount;

    final breakdown = {
      'theaterPrice': theaterDiscountedPrice,
      'transactionFee': double.parse(transactionFee.toStringAsFixed(2)),
      'totalAmount': double.parse(totalAmount.toStringAsFixed(2)),
    };

    if (vendorHasGst) {
      breakdown['gst'] = double.parse(gstAmount.toStringAsFixed(2));
    }

    return breakdown;
  }

  /// Get breakdown of price components for THEATER DETAIL/CHECKOUT using RPC
  /// Uses: calculate_theater_detail_price RPC function (ASYNC - for accurate server-side calculation)
  static Future<Map<String, double>> getTheaterCheckoutPriceBreakdownRPC(
    double theaterDiscountedPrice, {
    bool vendorHasGst = false,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'calculate_theater_detail_price',
        params: {
          'p_theater_price': theaterDiscountedPrice,
          'p_vendor_has_gst': vendorHasGst,
        },
      );

      if (response != null) {
        final result = response as Map<String, dynamic>;
        final breakdown = {
          'theaterPrice': (result['theater_price'] as num).toDouble(),
          'transactionFee': (result['transaction_fee'] as num).toDouble(),
          'totalAmount': (result['total_amount'] as num).toDouble(),
        };

        // Add GST to breakdown if vendor has GST
        if (vendorHasGst && result['gst_amount'] != null) {
          breakdown['gst'] = (result['gst_amount'] as num).toDouble();
        }

        return breakdown;
      }
    } catch (e) {
      debugPrint('Error getting theater price breakdown via RPC: $e');
      // Fallback to local calculation
    }

    // Fallback calculation
    final transactionFee = theaterDiscountedPrice * transactionFeeRate;
    final gstAmount = vendorHasGst ? theaterDiscountedPrice * gstRate : 0.0;
    final totalAmount = theaterDiscountedPrice + transactionFee + gstAmount;

    final breakdown = {
      'theaterPrice': theaterDiscountedPrice,
      'transactionFee': double.parse(transactionFee.toStringAsFixed(2)),
      'totalAmount': double.parse(totalAmount.toStringAsFixed(2)),
    };

    if (vendorHasGst) {
      breakdown['gst'] = double.parse(gstAmount.toStringAsFixed(2));
    }

    return breakdown;
  }
}
