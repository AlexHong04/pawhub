import 'package:flutter/material.dart';
// import 'package:pratical_exercises/core/theme/app_theme.dart';
// import 'package:pratical_exercises/module/auth/auth_routes.dart';
// import 'package:pratical_exercises/module/auth/auth_service.dart';
// import 'package:pratical_exercises/module/home/home_routes.dart';

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

    // AuthService.listenToAuthChanges(() {
    //   navigatorKey.currentState?.pushNamedAndRemoveUntil(
    //     AuthRoutes.login,
    //         (route) => false,
    //   );
    // });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Authentication",
      debugShowCheckedModeBanner: false,
      //
      // theme: AppTheme.lightTheme,
      //
      // initialRoute: AuthRoutes.login,
      //
      // routes: {...AuthRoutes.routes, ...HomeRoutes.routes},
    );
  }
}
