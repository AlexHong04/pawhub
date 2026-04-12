import 'dart:io';

import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_file_service.dart';

class ProfileService {
  static final supabase = Supabase.instance.client;

  static Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found or user ID mismatch.');
        return null;
      }
      final data = await supabase
          .from('User')
          .select()
          .eq('auth_id', user.id)
          .single();

      data['email'] = user.email;
      return UserModel.fromJson(data);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<String?> uploadAvatar(File imageFile) async {
    // try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // final fileExtension = imageFile.path.split('.').last;
      // final fileName = 'profile/${user.id}_avatar.$fileExtension';
      //
      // const bucketCandidates = ['avatars', 'documents'];
      // for (final bucket in bucketCandidates) {
      //   try {
      //     await supabase.storage.from(bucket).upload(
      //       fileName,
      //       imageFile,
      //       fileOptions: const FileOptions(upsert: true),
      //     );
      //
      //     final imageUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
      //     // Cache-bust so the latest image is shown after updating.
      //     return '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      //   } catch (_) {
      //     // Try next configured bucket.
      //   }
      // }

      return await SupabaseFileService.uploadImage(
        imageFile: imageFile,
        bucketName: 'documents',     // The bucket
        folderPath: 'profile',     // The folder inside the bucket
        fileNamePrefix: user.id,   // The unique ID
      );

    //   print('Error uploading avatar: no usable storage bucket found (avatars/documents).');
    //   return null;
    //
    // } catch (e) {
    //   print('Error uploading avatar: $e');
    //   return null;
    // }
  }

  static Future<bool> updateProfile(
      String name,
      String email,
      String gender,
      String contact,
      String address,
      String? avatarUrl
      ) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found or user ID mismatch.');
        return false;
      }

      // Update Email in Auth (if it changed)
      if (user.email != email) {
        await supabase.auth.updateUser(
          UserAttributes(email: email),
        );
      }

      // Build the exact map of data we want to save
      final Map<String, dynamic> updates = {
        'name': name,
        'gender': gender,
        'contact': contact,
        'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add the image URL to the map ONLY if they uploaded a new one
      if(avatarUrl != null && avatarUrl.isNotEmpty){
        updates['avatar_url'] = avatarUrl;
      }

      // Make exactly ONE database call
      await supabase.from('User').update(updates).eq('auth_id', user.id);

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
  static Future<List<UserModel>> getAllUsers() async {
    try {
      // Fetch all rows from the public.User table
      final data = await supabase.from('User').select();

      // Convert the raw JSON data into a List of UserModels
      return (data as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return []; // Return empty list if it fails
    }
  }
}