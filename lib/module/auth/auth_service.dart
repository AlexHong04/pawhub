
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Profile/profile_model.dart';

class AuthService {
  // static const email = 'Hong@gmail.com';
  // static const password = '123456';

  static final supabase = Supabase.instance.client;

  static Future<AuthModel?> login(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if(response.session != null && response.user != null){
        final userData = await supabase.from('users').select().eq('user_id', response.user!.id).single();
        final userModel = AuthModel.fromJson(userData);
        return userModel;
      }
      return null;
    } catch (e) {
      print('login error: $e');
      return null;
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
