import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../repositories/booking_repository.dart';

class BookingService {
  final BookingRepository _repository;

  BookingService(this._repository);

  /// Validate and create a booking with all required checks
  Future<BookingValidationResult> validateAndCreateBooking({
    required String userId,
    required String vendorId,
    required String serviceListingId,
    required String serviceTitle,
    required DateTime bookingDate,
    required String bookingTime,
    required String customerName,
    required String customerPhone,
    required String venueAddress,
    required double totalAmount,
    String? serviceDescription,
    String? customerEmail,
    Map<String, dynamic>? venueCoordinates,
    String? specialRequirements,
    List<Map<String, dynamic>>? addOns,
  }) async {
    try {
      // Parse booking time (e.g., "14:00-16:00")
      final timeParts = bookingTime.split('-');
      if (timeParts.length != 2) {
        return BookingValidationResult.error('Invalid booking time format. Expected format: HH:MM-HH:MM');
      }

      final startTime = timeParts[0].trim();
      final endTime = timeParts[1].trim();

      // Create booking DateTime for validation
      final bookingDateTime = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        int.parse(startTime.split(':')[0]),
        int.parse(startTime.split(':')[1]),
      );

      // 1. Check if booking is in the future
      if (bookingDateTime.isBefore(DateTime.now())) {
        return BookingValidationResult.error('Cannot book a time slot in the past');
      }

      // 2. Check if booking is at least 2 hours in advance
      final minimumAdvanceTime = DateTime.now().add(const Duration(hours: 2));
      if (bookingDateTime.isBefore(minimumAdvanceTime)) {
        return BookingValidationResult.error('Booking must be at least 2 hours in advance');
      }

      // 3. Check if the time slot is available
      final isSlotAvailable = await _repository.isTimeSlotAvailable(
        vendorId: vendorId,
        serviceListingId: serviceListingId,
        date: bookingDate,
        startTime: startTime,
        endTime: endTime,
      );

      if (!isSlotAvailable) {
        return BookingValidationResult.error('Selected time slot is not available');
      }

      // 4. Check for conflicting bookings
      final hasConflicts = await _repository.hasConflictingBookings(
        vendorId: vendorId,
        bookingDate: bookingDate,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasConflicts) {
        return BookingValidationResult.error('There is a conflicting booking for this time slot');
      }

      // 5. Validate booking time is greater than inquiry time
      final isTimeValid = await _repository.validateBookingTimeAfterInquiry(
        vendorId: vendorId,
        bookingDateTime: bookingDateTime,
      );

      if (!isTimeValid) {
        return BookingValidationResult.error('Booking time must be after the service provider\'s inquiry time');
      }

      // 6. Validate customer information
      final customerValidation = _validateCustomerInfo(customerName, customerPhone, customerEmail);
      if (!customerValidation.isValid) {
        return BookingValidationResult.error(customerValidation.message);
      }

      // 7. Validate venue address
      if (venueAddress.trim().isEmpty) {
        return BookingValidationResult.error('Venue address is required');
      }

      // 8. Validate total amount
      if (totalAmount <= 0) {
        return BookingValidationResult.error('Total amount must be greater than 0');
      }

      // All validations passed, create the booking
      final booking = await _repository.createBooking(
        userId: userId,
        vendorId: vendorId,
        serviceListingId: serviceListingId,
        serviceTitle: serviceTitle,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        customerName: customerName,
        customerPhone: customerPhone,
        venueAddress: venueAddress,
        totalAmount: totalAmount,
        serviceDescription: serviceDescription,
        customerEmail: customerEmail,
        venueCoordinates: venueCoordinates,
        specialRequirements: specialRequirements,
        addOns: addOns,
      );

      // Reserve the time slot
      await _repository.reserveTimeSlot(
        vendorId: vendorId,
        serviceListingId: serviceListingId,
        date: bookingDate,
        startTime: startTime,
        endTime: endTime,
        bookingId: booking.id,
      );

      return BookingValidationResult.success(booking);
    } catch (e) {
      //('Error creating booking: $e');
      return BookingValidationResult.error('Failed to create booking: ${e.toString()}');
    }
  }

  /// Get available time slots for a service
  Future<List<TimeSlotModel>> getAvailableTimeSlots({
    required String vendorId,
    required String serviceListingId,
    required DateTime date,
  }) async {
    try {
      return await _repository.getAvailableTimeSlots(
        vendorId: vendorId,
        serviceListingId: serviceListingId,
        date: date,
      );
    } catch (e) {
      //('Error getting available time slots: $e');
      return [];
    }
  }

  /// Generate default time slots for a date (if none exist)
  Future<List<TimeSlotModel>> generateDefaultTimeSlots({
    required String vendorId,
    required String serviceListingId,
    required DateTime date,
  }) async {
    try {
      // Check if time slots already exist for this date
      final existingSlots = await getAvailableTimeSlots(
        vendorId: vendorId,
        serviceListingId: serviceListingId,
        date: date,
      );

      if (existingSlots.isNotEmpty) {
        return existingSlots;
      }

      // Generate default time slots (9 AM to 6 PM, 2-hour slots)
      final defaultSlots = <Map<String, dynamic>>[];
      for (int hour = 9; hour < 18; hour += 2) {
        final startTime = '${hour.toString().padLeft(2, '0')}:00';
        final endTime = '${(hour + 2).toString().padLeft(2, '0')}:00';

        defaultSlots.add({
          'vendor_id': vendorId,
          'service_listing_id': serviceListingId,
          'date': date.toIso8601String().split('T')[0],
          'start_time': startTime,
          'end_time': endTime,
          'is_available': true,
          'is_blocked': false,
        });
      }

      // Insert default slots into database (this would need to be added to repository)
      // For now, return empty list and let UI handle slot generation
      return [];
    } catch (e) {
      //('Error generating default time slots: $e');
      return [];
    }
  }

  /// Cancel a booking
  Future<BookingActionResult> cancelBooking({
    required String bookingId,
    required String userId,
    String? reason,
  }) async {
    try {
      // Get the booking first
      final booking = await _repository.getBookingById(bookingId);
      if (booking == null) {
        return BookingActionResult.error('Booking not found');
      }

      // Check if user owns the booking
      if (booking.userId != userId) {
        return BookingActionResult.error('Unauthorized to cancel this booking');
      }

      // Check if booking can be cancelled (not already completed or cancelled)
      if (booking.status == 'completed' || booking.status == 'cancelled') {
        return BookingActionResult.error('Cannot cancel a ${booking.status} booking');
      }

      // Update booking status to cancelled
      final updatedBooking = await _repository.updateBookingStatus(
        bookingId: bookingId,
        status: 'cancelled',
      );

      // Release the time slot
      final timeParts = booking.bookingTime.split('-');
      final startTime = timeParts[0].trim();
      final endTime = timeParts[1].trim();

      await _repository.releaseTimeSlot(
        vendorId: booking.vendorId,
        date: booking.bookingDate,
        startTime: startTime,
        endTime: endTime,
      );

      return BookingActionResult.success(updatedBooking);
    } catch (e) {
      //('Error cancelling booking: $e');
      return BookingActionResult.error('Failed to cancel booking: ${e.toString()}');
    }
  }

  /// Get booking details with related information
  Future<BookingDetailsResult> getBookingDetails(String bookingId) async {
    try {
      final booking = await _repository.getBookingById(bookingId);
      if (booking == null) {
        return BookingDetailsResult.error('Booking not found');
      }

      return BookingDetailsResult.success(booking);
    } catch (e) {
      //('Error getting booking details: $e');
      return BookingDetailsResult.error('Failed to get booking details: ${e.toString()}');
    }
  }

  /// Get user's booking history
  Future<List<BookingModel>> getUserBookingHistory(String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _repository.getUserBookings(userId, limit: limit, offset: offset);
    } catch (e) {
      //('Error getting user booking history: $e');
      return [];
    }
  }

  /// Calculate payment breakdown
  Map<String, double> calculatePaymentBreakdown(double totalAmount) {
    final razorpayAmount = totalAmount * 0.6; // 60%
    final sylonowQrAmount = totalAmount * 0.4; // 40%

    return {
      'total': totalAmount,
      'razorpay': razorpayAmount,
      'sylonow_qr': sylonowQrAmount,
    };
  }

  /// Validate customer information
  ValidationResult _validateCustomerInfo(String name, String phone, String? email) {
    if (name.trim().isEmpty) {
      return ValidationResult(isValid: false, message: 'Customer name is required');
    }

    if (phone.trim().isEmpty) {
      return ValidationResult(isValid: false, message: 'Customer phone is required');
    }

    // Basic phone validation (Indian format)
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''))) {
      return ValidationResult(isValid: false, message: 'Please enter a valid phone number');
    }

    // Email validation (if provided)
    if (email != null && email.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        return ValidationResult(isValid: false, message: 'Please enter a valid email address');
      }
    }

    return ValidationResult(isValid: true, message: '');
  }
}

// Result classes for type-safe returns
class BookingValidationResult {
  final bool isSuccess;
  final String message;
  final BookingModel? booking;

  BookingValidationResult._({
    required this.isSuccess,
    required this.message,
    this.booking,
  });

  factory BookingValidationResult.success(BookingModel booking) {
    return BookingValidationResult._(
      isSuccess: true,
      message: 'Booking created successfully',
      booking: booking,
    );
  }

  factory BookingValidationResult.error(String message) {
    return BookingValidationResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class BookingActionResult {
  final bool isSuccess;
  final String message;
  final BookingModel? booking;

  BookingActionResult._({
    required this.isSuccess,
    required this.message,
    this.booking,
  });

  factory BookingActionResult.success(BookingModel booking) {
    return BookingActionResult._(
      isSuccess: true,
      message: 'Action completed successfully',
      booking: booking,
    );
  }

  factory BookingActionResult.error(String message) {
    return BookingActionResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class BookingDetailsResult {
  final bool isSuccess;
  final String message;
  final BookingModel? booking;

  BookingDetailsResult._({
    required this.isSuccess,
    required this.message,
    this.booking,
  });

  factory BookingDetailsResult.success(BookingModel booking) {
    return BookingDetailsResult._(
      isSuccess: true,
      message: 'Booking details retrieved successfully',
      booking: booking,
    );
  }

  factory BookingDetailsResult.error(String message) {
    return BookingDetailsResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult({required this.isValid, required this.message});
} 