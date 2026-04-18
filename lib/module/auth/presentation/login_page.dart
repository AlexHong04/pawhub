import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
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
  bool obscurePassword = true;

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
          if (userData.role == 'Admin') {
            Navigator.pushReplacementNamed(context, '/staff_layout');
          } else {
            Navigator.pushReplacementNamed(context, '/user_layout');
          }
        } else {
          final message = AuthService.lastError ?? 'Invalid email or password';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
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
                  Image.asset(
                    'assets/images/registerLogo.png',
                    height: 130,
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
                          prefixIcon: Icons.lock,
                          labelText: "Password",
                        ).copyWith(
                          suffixIcon: PasswordSuffix(
                            showCheck: false,
                            isObscure: obscurePassword,
                            onToggleVisibility: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return "Password must be at least 8 characters";
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
                        loading ? 'Logging In...' : "login",
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
                      onPressed: () {
                        // handle google sign in
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.google,
                        size: 20,
                        color: AppColors.textDark,
                      ),
                      // icon: Image.asset('assets/images/googleLogo.jpg', height: 24),
                      label: Text(
                        "Google",
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
