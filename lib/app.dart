import 'package:flutter/material.dart';
import 'package:pawhub/module/Profile/profile_routes.dart';
import 'module/auth/auth_routes.dart';
import 'module/auth/presentation/login_page.dart';
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
  late Future<String> _initialRouteFuture;

  @override
  void initState() {
    super.initState();

    _initialRouteFuture = _determineInitialRoute();

    AuthService.listenToAuthChanges(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AuthRoutes.login,
        (route) => false,
      );
    });
  }

  Future<String> _determineInitialRoute() async {
    final cachedUser = await AuthService.getStoredCurrentUser();

    if (AuthService.isLoggedIn()) {
      if (cachedUser?.role == 'Admin') {
        return '/staff_layout';
      }
      return '/user_layout';
    }

    return AuthRoutes.login;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Authentication",
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: FutureBuilder<String>(
        future: _initialRouteFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final route = snapshot.data ?? AuthRoutes.login;
          if (route == '/staff_layout') return const StaffLayout();
          if (route == '/user_layout') return const UserLayout();
          return const LoginPage();
        },
      ),
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
