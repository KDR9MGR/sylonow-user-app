import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import '../models/time_slot_model.dart';

class TheaterScreenDetailService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get available time slots for a specific screen and date
  Future<List<TimeSlotModel>> getTimeSlotsByScreenAndDate(String screenId, String date) async {
    try {
      print('Fetching time slots for screen: $screenId, date: $date');

      // Step 1: Get the theater_id from screen
      final screenResponse = await _supabase
          .from('theater_screens')
          .select('theater_id')
          .eq('id', screenId)
          .single();

      final theaterId = screenResponse['theater_id'] as String;
      print('Found theater ID: $theaterId');

      // Step 2: Get time slots for this theater (using raw prices without tax)
      final timeSlotsResponse = await _supabase
          .from('theater_time_slots')
          .select('''
            id,
            theater_id,
            screen_id,
            start_time,
            end_time,
            base_price,
            discounted_price,
            is_available,
            is_active,
            created_at,
            updated_at
          ''')
          .eq('theater_id', theaterId)
          .eq('is_active', true)
          .order('start_time', ascending: true);

      if (timeSlotsResponse.isEmpty) {
        print('No time slots found for theater: $theaterId');
        return [];
      }

      print('Found ${timeSlotsResponse.length} time slots for theater');

      // Step 3: Get existing bookings for this date
      final bookingsResponse = await _supabase
          .from('theater_time_slot_bookings')
          .select('time_slot_id')
          .eq('booked_date', date);

      final bookedSlotIds = bookingsResponse
          .map((booking) => booking['time_slot_id'] as String)
          .toSet();

      print('Found ${bookedSlotIds.length} booked slots for date: $date');

      // Step 4: Fetch admin settings for price calculation
      final settings = await _supabase
          .from('admin_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', ['percent_tax']);

      double percentTax = 3.54;
      for (final setting in settings) {
        if (setting['setting_key'] == 'percent_tax') {
          percentTax = (setting['setting_value'] as num).toDouble();
        }
      }

      // Step 5: Convert to TimeSlotModel with booking status and calculated prices
      final timeSlots = timeSlotsResponse.map((slotData) {
        final isBooked = bookedSlotIds.contains(slotData['id'] as String);
        final rawBasePrice = (slotData['base_price'] as num?)?.toDouble() ?? 0.0;

        // Calculate final price: base + 19 + (base * tax%)
        final calculatedPrice = rawBasePrice + 19 + (rawBasePrice * percentTax / 100);
        final roundedFinalPrice = PriceRounding.applyFinalRounding(calculatedPrice);

        return TimeSlotModel.fromJson({
          ...slotData,
          'base_price': roundedFinalPrice, // Use calculated final price
          'is_booked': isBooked,
        });
      }).toList();

      print('Successfully processed ${timeSlots.length} time slots');
      return timeSlots;
    } catch (e, stackTrace) {
      print('Error fetching time slots: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Check if a specific time slot is available for booking
  Future<bool> isTimeSlotAvailable(String timeSlotId, String date) async {
    try {
      final response = await _supabase
          .from('theater_time_slot_bookings')
          .select('id')
          .eq('time_slot_id', timeSlotId)
          .eq('booked_date', date)
          .limit(1);

      return response.isEmpty;
    } catch (e) {
      print('Error checking time slot availability: $e');
      return false;
    }
  }

  /// Book a time slot
  Future<bool> bookTimeSlot(Map<String, dynamic> bookingData) async {
    try {
      print('Booking time slot with data: $bookingData');

      // Check if slot is still available
      final isAvailable = await isTimeSlotAvailable(
        bookingData['time_slot_id'] as String,
        bookingData['booked_date'] as String,
      );

      if (!isAvailable) {
        throw Exception('Time slot is no longer available');
      }

      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create booking in theater_time_slot_bookings
      await _supabase.from('theater_time_slot_bookings').insert({
        'time_slot_id': bookingData['time_slot_id'],
        'booked_date': bookingData['booked_date'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create detailed booking in private_theater_bookings
      await _supabase.from('private_theater_bookings').insert({
        'theater_id': bookingData['theater_id'],
        'screen_id': bookingData['screen_id'],
        'time_slot_id': bookingData['time_slot_id'],
        'user_id': user.id,
        'vendor_id': bookingData['vendor_id'], // You'll need to get this from theater data
        'booking_date': bookingData['booked_date'],
        'start_time': bookingData['start_time'],
        'end_time': bookingData['end_time'],
        'total_amount': bookingData['total_amount'],
        'payment_status': 'pending',
        'booking_status': 'confirmed',
        'guest_count': bookingData['guest_count'] ?? 1,
        'number_of_people': bookingData['number_of_people'] ?? 1,
        'contact_name': bookingData['contact_name'] ?? user.userMetadata?['name'] ?? 'Guest',
        'contact_phone': bookingData['contact_phone'] ?? user.phone ?? '',
        'contact_email': bookingData['contact_email'] ?? user.email ?? '',
        'celebration_name': bookingData['celebration_name'],
        'occasion_name': bookingData['occasion_name'],
        'occasion_id': bookingData['occasion_id'],
        'special_requests': bookingData['special_requests'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('Booking created successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error booking time slot: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get user's booking history
  Future<List<Map<String, dynamic>>> getUserBookingHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase
          .from('private_theater_bookings')
          .select('''
            *,
            theater_screens!inner(
              screen_name,
              theater_id
            ),
            theater_time_slots!inner(
              start_time,
              end_time
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching booking history: $e');
      return [];
    }
  }

  /// Get theater screens by theater ID (helper method)
  Future<List<Map<String, dynamic>>> getTheaterScreens(String theaterId) async {
    try {
      final response = await _supabase
          .from('theater_screens')
          .select('*')
          .eq('theater_id', theaterId)
          .eq('is_active', true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching theater screens: $e');
      return [];
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _supabase
          .from('private_theater_bookings')
          .update({
            'booking_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  /// Update booking payment status
  Future<bool> updatePaymentStatus(String bookingId, String paymentStatus, {String? paymentId}) async {
    try {
      final updateData = {
        'payment_status': paymentStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (paymentId != null) {
        updateData['payment_id'] = paymentId;
      }

      await _supabase
          .from('private_theater_bookings')
          .update(updateData)
          .eq('id', bookingId);

      return true;
    } catch (e) {
      print('Error updating payment status: $e');
      return false;
    }
  }
}