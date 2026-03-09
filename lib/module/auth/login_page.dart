import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';

import '../../core/constants/string.dart';

import 'auth_routes.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
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
    setState(() => loading = true);

    final success = await AuthService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => loading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid email or password')));
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBody,
                    ),
                  ),
                  SizedBox(height: 24),
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.pets, size: 60),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Pet Manager Login",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Access your adoption applications",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: AppStrings.email,
                      hintText: "you@example.com",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppStrings.forgotPassword,
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : () => login(),
                      child: Text(loading ? 'Logging In...' : AppStrings.login),
                    ),
                  ),
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.g_mobiledata),
                    label: Text("Google"),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
