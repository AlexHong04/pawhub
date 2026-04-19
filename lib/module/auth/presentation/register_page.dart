import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/app_snackbar.dart';
import 'package:pawhub/core/widgets/password_suffix.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';
import '../../../core/widgets/appDecorations.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final genderController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  bool get _isPasswordValid {
    final value = passwordController.text;
    return value.isNotEmpty &&
        value.trim().length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  bool get _isConfirmPasswordValid {
    final value = confirmPasswordController.text;
    return _isPasswordValid && value.isNotEmpty && value == passwordController.text;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    genderController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void register() async {
    // Hide the keyboard immediately to prevent TimeoutException
    FocusScope.of(context).unfocus();
    if (formKey.currentState!.validate()) {
      setState(() {
        loading = true;
      });

      final user = await AuthService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text.trim(),
        genderController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (user != null) {
        AppSnackBar.success(context, 'Registration Successful');

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      } else {
        final errorMessage = AuthService.lastError ?? 'Registration Failed';
        AppSnackBar.error(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    // wrapped the column in a form widget
                    child: Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Register",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBody,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Image.asset(
                            'assets/images/registerLogo.png',
                            height: 100,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Create an account to find your new best friend.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: nameController,
                            decoration: AppDecorations.outlineInputDecoration(
                              hintText: "Eg. Tan Kok Hong",
                              prefixIcon: Icons.person_outline,
                              labelText: 'Full Name',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter your full name";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailController,
                            decoration: AppDecorations.outlineInputDecoration(
                              hintText: "Eg. hong@gmail.com",
                              prefixIcon: Icons.mail_outline,
                              labelText: 'Email Address',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter your email";
                              }
                              final emailRegex =
                              RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value)) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: genderController.text.isEmpty ? null : genderController.text,
                            items: const [
                              DropdownMenuItem(value: "Male", child: Text("Male")),
                              DropdownMenuItem(value: "Female", child: Text("Female")),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                genderController.text = value;
                              }
                            },
                            // Added validation to prevent database errors!
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please select your gender";
                              }
                              return null;
                            },
                            decoration: AppDecorations.outlineInputDecoration(
                              hintText: "Select gender",
                              prefixIcon: Icons.wc,
                              labelText: 'Gender',
                            ),
                            // Keeps the dropdown menu background clean and white
                            dropdownColor: AppColors.white,
                            // Styles the little arrow on the right
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.iconColor),
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
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscurePassword,
                            decoration:
                            AppDecorations.outlineInputDecoration(
                              hintText: "••••••••",
                              prefixIcon: Icons.verified_user_outlined,
                              labelText: "Confirm Password",
                            ).copyWith(
                              suffixIcon: AnimatedBuilder(
                                animation: Listenable.merge([
                                  passwordController,
                                  confirmPasswordController,
                                ]),
                                builder: (context, _) => PasswordSuffix(
                                  showCheck: _isConfirmPasswordValid,
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
                              if (value != passwordController.text) {
                                return "Password do not match";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // sign up button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: loading ? null : register,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    loading
                                        ? "Creating Account ..."
                                        : "Sign Up",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!loading) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 20),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // back button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(color: AppColors.border),
                                // Using your border color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/login',
                                  );
                                }
                              },
                              child: const Text(
                                "Back to Login",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
