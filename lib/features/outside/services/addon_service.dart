import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/addon_model.dart';

class AddonService {
  final SupabaseClient _supabase;

  AddonService(this._supabase);

  /// Get all active addons
  Future<List<AddonModel>> getActiveAddons() async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error fetching active addons: $e');
      return [];
    }
  }

  /// Get addon details by their IDs
  Future<List<AddonModel>> getAddonsByIds(List<String> addonIds) async {
    try {
      if (addonIds.isEmpty) {
        return [];
      }

      print('Fetching addons for IDs: $addonIds');

      final response = await _supabase
          .from('add_ons')
          .select('*')
          .inFilter('id', addonIds)
          .eq('is_active', true);

      if (response.isEmpty) {
        print('No addons found for IDs: $addonIds');
        return [];
      }

      final addons = response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();

      print('Successfully fetched ${addons.length} addons');
      return addons;
    } catch (e, stackTrace) {
      print('Error fetching addons by IDs: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get all addons for a specific theater
  Future<List<AddonModel>> getAddonsByTheaterId(String theaterId) async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('theater_id', theaterId)
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error fetching addons by theater ID: $e');
      return [];
    }
  }

  /// Get addon by ID
  Future<AddonModel?> getAddonById(String addonId) async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('id', addonId)
          .eq('is_active', true)
          .single();

      return AddonModel.fromJson(response);
    } catch (e) {
      print('Error fetching addon by ID: $e');
      return null;
    }
  }

  /// Get addons by category
  Future<List<AddonModel>> getAddonsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('category', category)
          .eq('is_active', true)
          .order('price', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error fetching addons by category: $e');
      return [];
    }
  }

  /// Search addons by name
  Future<List<AddonModel>> searchAddons(String query) async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error searching addons: $e');
      return [];
    }
  }

  /// Get addons by vendor and category
  /// Filters addons by vendor_id (theater owner)
  Future<List<AddonModel>> getAddonsByVendorAndCategory(
    String vendorId,
    String category,
  ) async {
    try {
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('category', category)
          .eq('is_active', true)
          .eq('vendor_id', vendorId)
          .order('price', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error fetching addons by vendor and category: $e');
      return [];
    }
  }

  /// Get addons by theater and category
  /// Includes both theater-specific addons (theater_id match) AND vendor-owned addons (vendor_id match)
  Future<List<AddonModel>> getAddonsByTheaterAndCategory(
    String theaterId,
    String category,
  ) async {
    try {
      // First get the theater's vendor/owner ID
      final theaterResponse = await _supabase
          .from('private_theaters')
          .select('owner_id')
          .eq('id', theaterId)
          .single();

      final vendorId = theaterResponse['owner_id'] as String?;

      if (vendorId == null) {
        print('No vendor ID found for theater: $theaterId');
        return [];
      }

      // Fetch addons that match category AND (theater_id = theaterId OR vendor_id = vendorId)
      final response = await _supabase
          .from('add_ons')
          .select('*')
          .eq('category', category)
          .eq('is_active', true)
          .or('theater_id.eq.$theaterId,vendor_id.eq.$vendorId')
          .order('price', ascending: true);

      return response.map((addonData) {
        return AddonModel.fromJson(addonData);
      }).toList();
    } catch (e) {
      print('Error fetching addons by theater and category: $e');
      return [];
    }
  }
}
