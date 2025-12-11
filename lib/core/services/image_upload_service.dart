import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  /// Show image source selection dialog
  Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Select Image Source',
            style: TextStyle(
              fontFamily: 'Okra',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text(
                  'Camera',
                  style: TextStyle(fontFamily: 'Okra'),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text(
                  'Gallery',
                  style: TextStyle(fontFamily: 'Okra'),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pick image from camera or gallery
  Future<XFile?> pickImage({ImageSource? source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source ?? ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      //('❌ Error picking image: $e');
      return null;
    }
  }

  /// Upload image to Supabase storage
  Future<String?> uploadPlaceImage({
    required XFile imageFile,
    required String userId,
    String? orderId,
  }) async {
    try {
      //('🔄 Starting image upload...');
      
      // Generate unique filename
      final String fileName = 
          '${orderId ?? _uuid.v4()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '$userId/$fileName';

      //('📁 Upload path: $filePath');

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Upload to Supabase storage
      final String uploadPath = await _supabase.storage
          .from('place-images')
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      //('✅ Image uploaded successfully: $uploadPath');

      // Get public URL
      final String publicUrl = _supabase.storage
          .from('place-images')
          .getPublicUrl(filePath);

      //('🔗 Public URL: $publicUrl');
      return publicUrl;

    } catch (e) {
      //('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Delete image from Supabase storage
  Future<bool> deletePlaceImage({required String imageUrl}) async {
    try {
      // Extract file path from URL
      final Uri uri = Uri.parse(imageUrl);
      final String filePath = uri.pathSegments.last;
      
      await _supabase.storage
          .from('place-images')
          .remove([filePath]);

      //('✅ Image deleted successfully: $filePath');
      return true;
    } catch (e) {
      //('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Compress image file size
  Future<XFile?> compressImage(XFile imageFile) async {
    try {
      // For now, just return the original file
      // In a production app, you might want to use image compression libraries
      return imageFile;
    } catch (e) {
      //('❌ Error compressing image: $e');
      return null;
    }
  }

  /// Validate image file
  bool validateImageFile(XFile imageFile) {
    // Note: File size validation would need to be checked after reading the file
    // as XFile from image_picker doesn't provide size directly
    
    // Check file extension
    final String extension = imageFile.path.split('.').last.toLowerCase();
    final List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
    
    return allowedExtensions.contains(extension);
  }
}