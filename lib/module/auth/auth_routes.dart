import 'package:pawhub/module/auth/presentation/forgotPassword.dart';
import 'package:pawhub/module/auth/presentation/newPassword_page.dart';
import 'package:pawhub/module/auth/presentation/otpVefification_page.dart';
import 'presentation/register_page.dart';
import 'presentation/login_page.dart';

class AuthRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgotPassword';
  static const otpVerify = '/otp_verification';
  static const newPassword = 'set_new_password';

  static final routes = {
    login: (context) => LoginPage(),
    register: (context) => RegisterPage(),
    forgotPassword: (context) => ForgotPasswordPage(),
    otpVerify: (context) => OtpVerificationPage(),
    newPassword: (context) => SetNewPasswordPage(),
  };
}
