import 'presentation/register_page.dart';
import 'presentation/login_page.dart';

class AuthRoutes {
  static const login = '/login';
  static const register = '/register';
  static final routes = {
    login: (context) => LoginPage(),
    register: (context) => RegisterPage(),
  };
}
