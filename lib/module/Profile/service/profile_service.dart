import 'dart:io';

import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_file_service.dart';

class ProfileService {
  static final supabase = Supabase.instance.client;
  static const Duration onlineFreshness = Duration(minutes: 2);

  static Future<void> updateOnlineStatus(String authId, String status) async {
    try {
      await supabase.from('User').update({
        'online_status': status,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('auth_id', authId);
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  static bool isOnlineFromHeartbeat({
    required String status,
    required DateTime updatedAt,
    Duration freshness = onlineFreshness,
  }) {
    final normalized = status.trim().toLowerCase();
    final isMarkedOnline =
        normalized.contains('online') || normalized.contains('active');

    if (!isMarkedOnline) return false;

    final elapsed = DateTime.now().difference(updatedAt);
    return elapsed <= freshness;
  }

  static String resolvePresenceLabel(
    UserModel user, {
    Duration freshness = onlineFreshness,
  }) {
    return isOnlineFromHeartbeat(
      status: user.onlineStatus,
      updatedAt: user.updatedAt,
      freshness: freshness,
    )
        ? 'Online'
        : 'Offline';
  }

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

      if (data['email'] == null || data['email'].toString().trim().isEmpty) {
        data['email'] = user.email;
      }
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

      return await SupabaseFileService.uploadImage(
        imageFile: imageFile,
        bucketName: 'documents',     // The bucket
        folderPath: 'profile',     // The folder inside the bucket
        fileNamePrefix: user.id,   // The unique ID
      );
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

      final normalizedEmail = email.trim();

      // Update Email in Auth (if it changed)
      if (user.email != normalizedEmail) {
        await supabase.auth.updateUser(
          UserAttributes(email: normalizedEmail),
        );
      }

      // Build the exact map of data we want to save
      final Map<String, dynamic> updates = {
        'name': name,
        'email': normalizedEmail,
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
      final currentUser = supabase.auth.currentUser;

      // Fetch all rows from the public.User table
      final data = await supabase.from('User').select();

      // auth.currentUser only has the signed-in user's email.
      // For other rows, email must come from User.email in the database.
      return (data as List).map((json) {
        final row = Map<String, dynamic>.from(json as Map);

        if ((row['email'] == null || row['email'].toString().trim().isEmpty) &&
            currentUser != null &&
            row['auth_id'] == currentUser.id) {
          row['email'] = currentUser.email ?? '';
        }

        return UserModel.fromJson(row);
      }).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return []; // Return empty list if it fails
    }
  }
}