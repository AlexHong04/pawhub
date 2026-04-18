import 'dart:io';

import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/supabase_file_service.dart';

class ProfileService {
  static final supabase = Supabase.instance.client;
  static const Duration onlineFreshness = Duration(minutes: 2);

  static Future<bool> updateOnlineStatus(String authId, String status) async {
    try {
      final updatedRow = await supabase.from('User').update({
        'online_status': status,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('auth_id', authId).select('auth_id, online_status, last_seen').maybeSingle();

      if (updatedRow == null) {
        print('updateOnlineStatus: no User row matched auth_id=$authId');
        return false;
      }

      return true;
    } on PostgrestException catch (e) {
      print('Error updating online status: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      print('Error updating online status: $e');
      return false;
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

  static Future<bool> updateUserRole(String userId, String role) async {
    try {
      final normalizedRole = role.trim();
      final updatedRow = await supabase.from('User').update({
        'role': normalizedRole,
        'is_volunteer': normalizedRole.toLowerCase() == 'volunteer',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).select('user_id, role').maybeSingle();

      if (updatedRow == null) {
        print('updateUserRole: no User row matched user_id=$userId');
        return false;
      }

      return true;
    } on PostgrestException catch (e) {
      print('Error updating user role: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  static Future<bool> updateUserBanStatus(String userId, bool isBanned) async {
    try {
      final updatedRow = await supabase
          .from('User')
          .update({
            'is_banned': isBanned,
            'online_status': isBanned ? 'Offline' : 'Online',
            'last_seen': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .select('user_id, is_banned')
          .maybeSingle();

      if (updatedRow == null) {
        print('updateUserBanStatus: no User row matched user_id=$userId');
        return false;
      }

      return true;
    } on PostgrestException catch (e) {
      print('Error updating user ban status: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      print('Error updating user ban status: $e');
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