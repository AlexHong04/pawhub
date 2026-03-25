import 'package:pawhub/module/Profile/presentation/peopleAndRoles_page.dart';
import 'package:pawhub/module/Profile/presentation/profileEdit_page.dart';
import 'package:pawhub/module/Profile/presentation/profile_page.dart';
import 'package:pawhub/module/Profile/presentation/resetPassword_page.dart';

class ProfileRoutes {
  static const profile = '/profile';
  static const editProfile = '/edit_profile';
  static const resetPassword = '/reset_password';
  static const peopleAndRoles = '/people_and_roles';
  static final routes = {
    profile: (context) => ProfilePage(),
    editProfile: (context) => ProfileEditPage(),
    resetPassword: (context) => ResetPasswordPage(),
    peopleAndRoles: (context) => PeopleAndRolesPage(),
  };
}
