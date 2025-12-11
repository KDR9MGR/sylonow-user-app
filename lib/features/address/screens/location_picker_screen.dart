import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:sylonow_user/core/providers/core_providers.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  static const routeName = '/location-picker';

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();

  // Default location (Mumbai)
  LatLng _currentPosition = const LatLng(19.0760, 72.8777);
  LatLng _pickedPosition = const LatLng(19.0760, 72.8777);
  String _selectedAddress = '';
  bool _isLoadingLocation = false;
  bool _isMovingMap = false;

  // Google Maps API Key for Places Autocomplete
  // IMPORTANT: This must be an UNRESTRICTED key (or HTTP referrer restricted)
  // because google_places_flutter makes HTTP API calls, not native SDK calls
  // DO NOT use the iOS/Android restricted keys here!
  static const String _googleApiKey = 'AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ';

  @override
  void initState() {
    super.initState();
    // Android-specific debug logging
    if (Platform.isAndroid && kDebugMode) {
      //('╔════════════════════════════════════════════════════════════');
      //('║ ANDROID MAP DEBUG - Location Picker Screen Initialized');
      //('╠════════════════════════════════════════════════════════════');
      //('║ Google Maps API Key (AndroidManifest.xml): AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U');
      //('║ Places API Key (HTTP): $_googleApiKey');
      //('║ Package Name: com.sylonowusr.app');
      //('║ Initial Position: ${_currentPosition.latitude}, ${_currentPosition.longitude}');
      //('╚════════════════════════════════════════════════════════════');
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    if (Platform.isAndroid && kDebugMode) {
      //('📍 [ANDROID] Getting current location...');
    }

    try {
      final locationService = ref.read(locationServiceProvider);

      // Check permission status first
      final permissionStatus = await locationService.getPermissionStatus();

      if (permissionStatus == LocationPermission.deniedForever) {
        // Permission permanently denied - show dialog to open settings
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (permissionStatus == LocationPermission.denied) {
        // Show rationale before requesting permission (required by stores)
        if (mounted) {
          final shouldRequest = await _showPermissionRationaleDialog();
          if (!shouldRequest) {
            setState(() => _isLoadingLocation = false);
            return;
          }
        }
      }

      final position = await locationService.getCurrentLocation();

      if (position != null) {
        final newPosition = LatLng(position.latitude, position.longitude);

        if (Platform.isAndroid && kDebugMode) {
          //('✅ [ANDROID] Location obtained: ${newPosition.latitude}, ${newPosition.longitude}');
        }

        setState(() {
          _currentPosition = newPosition;
          _pickedPosition = newPosition;
        });

        // Move camera to current location
        final controller = await _controller.future;

        if (Platform.isAndroid && kDebugMode) {
          //('📹 [ANDROID] Moving camera to location');
        }

        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPosition,
              zoom: 16.0,
            ),
          ),
        );

        // Get address for current location
        await _getAddressFromLatLng(newPosition);
      } else if (mounted) {
        // Permission denied or location service disabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location access is required to use this feature'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      if (Platform.isAndroid && kDebugMode) {
        //('❌ [ANDROID] Error getting location: $e');
        //('Stack trace: ${StackTrace.current}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);

      if (Platform.isAndroid && kDebugMode) {
        //('🏁 [ANDROID] Location loading completed');
      }
    }
  }

  Future<bool> _showPermissionRationaleDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Location Access'),
          ],
        ),
        content: const Text(
          'Sylonow needs access to your location to:\n\n'
          '• Show your current location on the map\n'
          '• Help you select accurate delivery addresses\n'
          '• Provide better service recommendations\n\n'
          'Your location data is only used for address selection and is not shared with third parties.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Access Denied'),
          ],
        ),
        content: const Text(
          'Location permission has been permanently denied. To use this feature, please enable location access in your device settings.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (Platform.isAndroid && kDebugMode) {
      //('🔍 [ANDROID] Geocoding position: ${position.latitude}, ${position.longitude}');
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = _formatAddress(place);

        if (Platform.isAndroid && kDebugMode) {
          //('✅ [ANDROID] Address found: $address');
        }

        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      if (Platform.isAndroid && kDebugMode) {
        //('❌ [ANDROID] Error getting address: $e');
      } else {
        //('Error getting address: $e');
      }
    }
  }

  String _formatAddress(Placemark place) {
    final parts = <String>[];

    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }

    return parts.join(', ');
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _isMovingMap = true;
      _pickedPosition = position.target;
    });
  }

  void _onCameraIdle() {
    setState(() {
      _isMovingMap = false;
    });
    _getAddressFromLatLng(_pickedPosition);
  }

  Future<void> _selectLocation(Prediction prediction) async {
    if (Platform.isAndroid && kDebugMode) {
      //('📌 [ANDROID] Place selected: ${prediction.description}');
    }

    // Get place details using geocoding
    try {
      // First try to get coordinates from prediction if available
      LatLng? newPosition;

      if (prediction.lat != null && prediction.lng != null) {
        // Use coordinates from prediction (more accurate)
        newPosition = LatLng(
          double.parse(prediction.lat!),
          double.parse(prediction.lng!),
        );
        //('Using coordinates from prediction: ${newPosition.latitude}, ${newPosition.longitude}');
      } else {
        // Fallback to geocoding
        //('Geocoding address: ${prediction.description}');
        final locations = await locationFromAddress(prediction.description ?? '');

        if (locations.isNotEmpty) {
          final location = locations.first;
          newPosition = LatLng(location.latitude, location.longitude);
          //('Using geocoded coordinates: ${newPosition.latitude}, ${newPosition.longitude}');
        }
      }

      if (newPosition != null && mounted) {
        // Update state first
        setState(() {
          _pickedPosition = newPosition!;
          _selectedAddress = prediction.description ?? '';
        });

        // Move camera to selected location with higher zoom for better accuracy
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPosition,
              zoom: 17.0, // Increased zoom level for better accuracy
              tilt: 0,
              bearing: 0,
            ),
          ),
        );

        // Update address from the new position
        await _getAddressFromLatLng(newPosition);

        // Clear search after animation completes
        if (mounted) {
          _searchController.clear();
          FocusScope.of(context).unfocus();
        }
      }
    } catch (e) {
      //('Error selecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting location: $e')),
        );
      }
    }
  }

  void _saveLocation() {
    // Return the selected location data
    context.pop({
      'latitude': _pickedPosition.latitude,
      'longitude': _pickedPosition.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 16.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              if (Platform.isAndroid && kDebugMode) {
                //('🗺️ [ANDROID] Google Map created successfully!');
                //('✅ [ANDROID] Map is rendering - API key is working');
              }
              _controller.complete(controller);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Center pin marker
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tooltip
                if (!_isMovingMap)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Move pin to your exact delivery location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),

                // Pin icon
                Icon(
                  Icons.location_pin,
                  size: 50,
                  color: AppTheme.primaryColor,
                  shadows: const [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black26,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),

                // Pin base
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Top UI
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => context.pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'Select delivery location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar with Places Autocomplete
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _searchController,
                        googleAPIKey: _googleApiKey,
                        inputDecoration: InputDecoration(
                          hintText: 'Search for area, street name...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontFamily: 'Okra',
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        debounceTime: 800,
                        countries: const ["in"],
                        isLatLngRequired: true,
                        getPlaceDetailWithLatLng: (Prediction prediction) {
                          _selectLocation(prediction);
                        },
                        itemClick: (Prediction prediction) {
                          _searchController.text = prediction.description ?? "";
                          _searchController.selection = TextSelection.fromPosition(
                            TextPosition(offset: prediction.description?.length ?? 0),
                          );
                        },
                        seperatedBuilder: const Divider(),
                        containerHorizontalPadding: 16,
                        itemBuilder: (context, index, Prediction prediction) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    prediction.description ?? "",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        isCrossBtnShown: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: AppTheme.primaryColor,
                    ),
            ),
          ),

          // Bottom Sheet with Address Details
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Selected Address Display
                      Row(
                        children: [
                          Icon(
                            Icons.location_pin,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedAddress.isEmpty
                                  ? 'Select a location on the map'
                                  : _selectedAddress,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Save Address Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedAddress.isEmpty ? null : _saveLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
