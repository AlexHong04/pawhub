import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/utils/biometric_session_service.dart';
import 'package:pawhub/core/widgets/password_suffix.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pawhub/module/auth/model/auth_model.dart';

import '../../../core/widgets/appDecorations.dart';
import '../service/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool googleLoading = false;
  bool biometricLoading = false;
  bool obscurePassword = true;

  bool get _isPasswordValid {
    final value = passwordController.text;
    return value.isNotEmpty &&
        value.trim().length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    if (formKey.currentState!.validate()) {
      setState(() {
        loading = true;
      });

      final AuthModel? userData = await AuthService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => loading = false);

        if (userData != null) {
          _navigateAfterLogin(userData);
        } else {
          final message = AuthService.lastError ?? 'Invalid email or password';
          _showSnackBar(message);
        }
      }
    }
  }

  Future<void> loginWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => googleLoading = true);

    final userData = await AuthService.loginWithGoogle();

    if (!mounted) return;
    setState(() => googleLoading = false);

    if (userData != null) {
      Navigator.pushReplacementNamed(context, '/user_layout');
      return;
    }

    final message =
        AuthService.lastError ?? 'Google login failed. Please try again.';
    _showSnackBar(message);
  }

  Future<void> loginWithBiometric() async {
    FocusScope.of(context).unfocus();

    if (loading || googleLoading || biometricLoading) return;

    final enabled = await BiometricSessionService.isEnabled();
    if (!enabled) {
      _showSnackBar('Enable biometric in Profile first, then use Lock App (not Sign Out).');
      return;
    }

    final hasStoredSession = await BiometricSessionService.hasStoredSession();
    if (!hasStoredSession) {
      _showSnackBar('No saved session. Sign Out clears biometric login; use normal login first.');
      return;
    }

    if (!mounted) return;
    setState(() => biometricLoading = true);

    final unlocked = await BiometricSessionService.authenticate(
      localizedReason: 'Scan to login with biometrics',
    );

    if (!mounted) return;
    if (!unlocked) {
      setState(() => biometricLoading = false);
      _showSnackBar('Biometric authentication failed.');
      return;
    }

    if (!AuthService.isLoggedIn()) {
      final restored = await BiometricSessionService.restoreSessionFromSecureStorage();
      if (!mounted) return;

      if (!restored) {
        setState(() => biometricLoading = false);
        _showSnackBar('Unable to restore your session. Please login with password.');
        return;
      }
    }

    AuthModel? userData = await AuthService.getStoredCurrentUser();
    userData ??= await AuthService.resolveCurrentUserFromActiveSession();

    if (!mounted) return;
    setState(() => biometricLoading = false);

    if (userData == null) {
      _showSnackBar('Session restored, but profile could not be loaded. Please login again.');
      return;
    }

    _navigateAfterLogin(userData);
  }

  void _navigateAfterLogin(AuthModel userData) {
    if (userData.role == 'Admin') {
      Navigator.pushReplacementNamed(context, '/staff_layout');
    } else {
      Navigator.pushReplacementNamed(context, '/user_layout');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child:Form(
                key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Welcome",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: biometricLoading ? null : loginWithBiometric,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: biometricLoading ? 0.55 : 1,
                          child: Image.asset(
                            'assets/images/registerLogo.png',
                            height: 130,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: biometricLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.fingerprint,
                                    size: 14,
                                    color: AppColors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Pet Login",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Access your adoption applications",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: AppDecorations.outlineInputDecoration(
                      labelText: "Email",
                      hintText: "you@example.com",
                      prefixIcon: Icons.email,
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration:
                    AppDecorations.outlineInputDecoration(
                      hintText: "••••••••",
                      prefixIcon: Icons.lock_outline,
                      labelText: "Password",
                    ).copyWith(
                      suffixIcon: AnimatedBuilder(
                        animation: passwordController,
                        builder: (context, _) => PasswordSuffix(
                          showCheck: _isPasswordValid,
                          isObscure: obscurePassword,
                          onToggleVisibility: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a password";
                      }
                      if (value.trim().length < 8) {
                        return "Password must be at least 8 characters";
                      }
                      if (!RegExp(r'\d').hasMatch(value)) {
                        return "Password must include at least 1 number";
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return "Password must include at least 1 uppercase letter";
                      }
                      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
                        return "Password must include at least 1 symbol";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/forgotPassword');
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        "forgotPassword",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : login,
                      child: Text(
                        loading ? 'Logging In...' : "Login",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign Up button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.border),
                        // Using your border color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/register');
                      },
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.borderGray,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR CONTINUE WITH",
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.borderGray,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // signup text
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading || googleLoading ? null : loginWithGoogle,
                      icon: const FaIcon(
                        FontAwesomeIcons.google,
                        size: 20,
                        color: AppColors.textDark,
                      ),
                      // icon: Image.asset('assets/images/googleLogo.jpg', height: 24),
                      label: Text(
                        googleLoading ? "Connecting..." : "Google",
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
