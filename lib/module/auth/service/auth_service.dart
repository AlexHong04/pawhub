import 'package:pawhub/core/utils/generatorId.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Profile/model/user_model.dart';
import '../model/auth_model.dart';

class AuthService {
  static final supabase = Supabase.instance.client;

  static Future<AuthModel?> login(String email, String password) async {
    try {
      // login in auth.users
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null && response.user != null) {
        // fetch data from public.User match with the user id column to the auth id
        final userData = await supabase
            .from('users')
            .select()
            .eq('user_id', response.user!.id)
            .single();

        // convert the database row into the userModel
        final userModel = AuthModel.fromJson(userData);
        return userModel;
      }
      return null;
    } catch (e) {
      print('login error: $e');
      return null;
    }
  }

  static Future<AuthModel?> register(
    String name,
    String email,
    String password,
    String gender,
  ) async {
    try {
      // create the user in auth.users
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        final String newUserId = await GeneratorId.generateId(
          tableName: 'User',
          idColumnName: 'User_id',
          prefix: 'U',
          numberLength: 5,
        );
        final userData = await supabase
            .from('User')
            .insert({
              'user_id': newUserId,
              'email': email,
              'name': name,
              'gender': gender,
              'contact': null,
              'role': 'User',
              'online_status': 'Online',
              'is_volunteer': false,
              'updated_at': null,
              'avatar_url': null,
              'auth_id': response.user!.id,
            })
            .select()
            .single();
        final userModel = AuthModel.fromJson(userData);
        return userModel;
      }
    } catch (e) {
      print('register error: $e');
      return null;
    }
    return null;
  }

  // send OTP to email
  static Future<bool> sendOtp(String email) async {
    try {
      await supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);
      return true;
    } catch (e) {
      print('sendOtp error: $e');
      return false;
    }
  }

  // verify OTP (return session if correct)
  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
      return response.session != null;
    } catch (e) {
      print('verifyOtp error: $e');
      return false;
    }
  }

  // update password after OTP verified
  static Future<bool> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      print('updatePassword error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  static bool isLoggedIn() {
    return supabase.auth.currentSession != null;
  }

  static void listenToAuthChanges(Function onSignedOut) {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedOut) {
        onSignedOut();
      }
    });
  }
}
