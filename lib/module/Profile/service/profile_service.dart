import 'dart:io';

import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/utils/supabase_file_service.dart';

class ProfileService {
  static final supabase = Supabase.instance.client;
  static const Duration onlineFreshness = Duration(minutes: 2);
  static String? lastError;

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

  static Future<UserModel?> getCurrentUserProfileWithTimeout({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      print('⏱️ Fetching user profile from Supabase (timeout: ${timeout.inSeconds}s)...');
      return await getCurrentUserProfile().timeout(timeout);
    } on TimeoutException catch (e) {
      print('⏰ Timeout fetching user profile (network unavailable?): $e');
      return null;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
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
      lastError = null;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found or user ID mismatch.');
        lastError = 'No authenticated user found.';
        return false;
      }

      final normalizedEmail = email.trim();
      final normalizedContact = contact.trim();

      if (normalizedContact.isNotEmpty) {
        final duplicateContactRow = await supabase
            .from('User')
            .select('auth_id')
            .eq('contact', normalizedContact)
            .neq('auth_id', user.id)
            .maybeSingle();

        if (duplicateContactRow != null) {
          lastError = 'This contact number is already used by another user.';
          return false;
        }
      }

      // Update Email in Auth (if it changed)
      if (user.email != normalizedEmail) {
        await supabase.auth.updateUser(
          UserAttributes(email: normalizedEmail),
        );
      }

      // Build the exact map of data we want to save
      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> updates = {
        'name': name,
        'email': normalizedEmail,
        'gender': gender,
        'contact': normalizedContact,
        'address': address,
        'updated_at': nowIso,
        // Keep presence alive when user actively saves profile changes.
        'last_seen': nowIso,
        'online_status': 'Online',
      };

      // Add the image URL to the map ONLY if they uploaded a new one
      if(avatarUrl != null && avatarUrl.isNotEmpty){
        updates['avatar_url'] = avatarUrl;
      }

      // Make exactly ONE database call
      await supabase.from('User').update(updates).eq('auth_id', user.id);

      return true;
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final isDuplicate =
          e.code == '23505' || message.contains('duplicate') || message.contains('unique');

      if (isDuplicate) {
        lastError = 'This contact number is already used by another user.';
      } else {
        lastError = e.message;
      }

      print('Error updating user profile: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      lastError = e.toString();
      print('Error updating user profile: $e');
      return false;
    }
  }

  static Future<bool> updateUserRole(
    String userId,
    String role, {
    bool? isVolunteer,
  }) async {
    try {
      final normalizedRole = role.trim();
      final normalizedRoleLower = normalizedRole.toLowerCase();
      final resolvedIsVolunteer =
          normalizedRoleLower == 'admin' ? false : (isVolunteer ?? false);

      final updatedRow = await supabase.from('User').update({
        'role': normalizedRole,
        'is_volunteer': resolvedIsVolunteer,
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

  static Future<List<UserModel>> getEventVolunteers(String eventId) async {
    try {
      final data = await supabase
          .from('JoinedEvent')
          .select('''
            User:user_id (
              user_id,
              name,
              gender,
              contact,
              address,
              role,
              online_status,
              is_volunteer,
              is_banned,
              last_seen,
              updated_at,
              avatar_url,
              email
            )
          ''')
          .eq('event_id', eventId);

      final Map<String, UserModel> uniqueUsers = {};
      for (final row in (data as List)) {
        final joinedRow = row as Map<String, dynamic>;
        final userData = joinedRow['User'];

        if (userData is Map<String, dynamic>) {
          final user = UserModel.fromJson(userData);
          uniqueUsers[user.id] = user;
          continue;
        }

        if (userData is List) {
          for (final item in userData) {
            if (item is Map<String, dynamic>) {
              final user = UserModel.fromJson(item);
              uniqueUsers[user.id] = user;
            }
          }
        }
      }

      return uniqueUsers.values.toList();
    } catch (e) {
      print('Error fetching event volunteers: $e');
      return [];
    }
  }
}