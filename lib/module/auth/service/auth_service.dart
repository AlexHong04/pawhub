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

  // static Future<bool> login(String email, String password) async {
  //   if (email == AuthService.email && password == AuthService.password) {
  //     final accessToken = TokenGenerator.tokenGenerator('U0001', expiresIn:Duration(days: 1));
  //     final refreshToken = TokenGenerator.tokenGenerator('U0001', expiresIn:Duration(days: 7));
  //     await TokenStorage.saveTokens(accessToken,refreshToken);
  //     return true;
  //   }
  //   return false;
  // }

  // check login state
  // static Future<bool> isLoggedIn() async{
  //   final access = await TokenStorage.getAccessToken();
  //   if (access == null){
  //     return false;
  //   }
  //   if(!TokenGenerator.tokenExpired(access)){
  //     return true;
  //   }
  //   return await refreshAccessToken();
  // }

  // static Future<bool> refreshAccessToken() async{
  //   final refresh = await TokenStorage.getRefreshToken();
  //   if (refresh == null){
  //     return false;
  //   }
  //   if (TokenGenerator.tokenExpired(refresh)){
  //     await TokenStorage.clear();
  //     return false;
  //   }
  //   final newAccessToken = TokenGenerator.tokenGenerator('U0001',   expiresIn: Duration(minutes: 5),);
  //
  //   await TokenStorage.saveTokens(newAccessToken, refresh);
  //   return true;
  // }

  // static Future<void> logout() async {
  //   await TokenStorage.clear();
  // }
}
