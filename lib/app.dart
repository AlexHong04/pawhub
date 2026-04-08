import 'package:flutter/material.dart';
import 'package:pawhub/module/Profile/profile_routes.dart';
import 'module/auth/auth_routes.dart';
import 'module/auth/service/auth_service.dart';
import 'module/home/home_routes.dart';
import 'module/home/staff_layout.dart';
import 'module/home/user_layout.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    AuthService.listenToAuthChanges(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AuthRoutes.login,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Authentication",
      debugShowCheckedModeBanner: false,

      initialRoute: '/login',

      routes: {
        ...AuthRoutes.routes,
        ...HomeRoutes.routes,
        ...ProfileRoutes.routes,
        '/user_layout': (context) => const UserLayout(),
        '/staff_layout': (context) => const StaffLayout(),
      },
    );
  }
}
