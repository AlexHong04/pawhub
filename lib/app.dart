import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pawhub/module/Profile/profile_routes.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';
import 'module/auth/auth_routes.dart';
import 'module/auth/presentation/login_page.dart';
import 'module/auth/service/auth_service.dart';
import 'module/home/home_routes.dart';
import 'module/home/staff_layout.dart';
import 'module/home/user_layout.dart';
import 'core/utils/biometric_session_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<String> _initialRouteFuture;
  Timer? _presenceTimer;
  static const Duration _presenceInterval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initialRouteFuture = _determineInitialRoute();

    AuthService.listenToAuthChanges(() {
      _stopPresenceHeartbeat();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AuthRoutes.login,
        (route) => false,
      );
    });

    _startPresenceHeartbeatIfLoggedIn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPresenceHeartbeat();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresenceHeartbeatIfLoggedIn();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPresenceHeartbeat();
    }
  }

  Future<void> _pingPresenceOnline() async {
    final authId = AuthService.supabase.auth.currentUser?.id;
    if (authId == null) return;

    await ProfileService.updateOnlineStatus(authId, 'Online');
  }

  void _startPresenceHeartbeatIfLoggedIn() {
    if (!AuthService.isLoggedIn()) return;

    _presenceTimer?.cancel();
    _pingPresenceOnline();
    _presenceTimer = Timer.periodic(_presenceInterval, (_) {
      _pingPresenceOnline();
    });
  }

  void _stopPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  Future<String> _determineInitialRoute() async {
    final hasActiveSession = AuthService.isLoggedIn();
    final hasStoredSession = await BiometricSessionService.hasStoredSession();
    final biometricEnabled = await BiometricSessionService.isEnabled();

    if (!hasActiveSession && hasStoredSession) {
      if (biometricEnabled) {
        final unlocked = await BiometricSessionService.authenticate();
        if (!unlocked) return AuthRoutes.login;
      }

      final restored = await BiometricSessionService.restoreSessionFromSecureStorage();
      if (!restored && !AuthService.isLoggedIn()) {
        return AuthRoutes.login;
      }
    } else if (hasActiveSession && biometricEnabled) {
      final unlocked = await BiometricSessionService.authenticate();
      if (!unlocked) return AuthRoutes.login;
    }

    if (!AuthService.isLoggedIn()) {
      return AuthRoutes.login;
    }

    final cachedUser = await AuthService.getStoredCurrentUser();
    if (cachedUser?.role == 'Admin') {
      return '/staff_layout';
    }
    return '/user_layout';
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
          // final route = '/staff_layout';
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
