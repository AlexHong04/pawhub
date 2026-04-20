import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseFileService {
  static final _supabase = Supabase.instance.client;

  // bucketName - e.g., 'avatars', 'pet_images', 'documents'
  // folderPath - e.g., 'profiles', 'dogs', 'medical_records'
  // fileNamePrefix  - e.g., 'user_123', 'pet_456'
  static Future<String?> uploadImage({
    required File imageFile,
    required String bucketName,
    required String folderPath,
    required String fileNamePrefix,
  }) async {
    try {
      final fileExtension = imageFile.path.split('.').last;

      // Combines your parameters to make: "profiles/user_123.jpg"
      final fullPath = '$folderPath/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Upload to the specific bucket requested
      await _supabase.storage.from(bucketName).upload(
        fullPath,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get the URL from that exact same bucket
      final imageUrl = _supabase.storage.from(bucketName).getPublicUrl(fullPath);

      // Return the URL with a cache-buster
      return '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    } catch (e) {
      debugPrint('SupabaseStorageHelper upload error: $e');
      return null;
    }
  }

  static Future<void> deleteImage({
    required String bucketName,
    required String folderPath,
    required String fileName,
  }) async {
    try {
      final path = '$folderPath/$fileName';

      debugPrint('Supabase delete path: $path');
      debugPrint('Bucket: $bucketName');

      final result = await _supabase.storage
          .from(bucketName)
          .remove([path]);

      debugPrint('Supabase delete result: $result');
    } catch (e) {
      debugPrint('Supabase delete error: $e');
      rethrow;
    }
  }
}