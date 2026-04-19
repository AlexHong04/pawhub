import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/app_snackbar.dart';
import 'package:pawhub/core/widgets/password_suffix.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';

import '../../../core/widgets/appDecorations.dart';

class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key});

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  bool loading = false;

  // THE MAGIC VARIABLE: Controls which UI to show
  bool isSuccess = false;

  bool get _isNewPasswordValid {
    final value = newPasswordController.text;
    return value.isNotEmpty &&
        value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  bool get _isConfirmPasswordValid {
    final value = confirmPasswordController.text;
    return value.isNotEmpty && value == newPasswordController.text;
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void updatePassword()async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => loading = true);

    bool success = await AuthService.updatePassword(newPasswordController.text);
    if (mounted) {
      setState(() => loading = false);
      if (success) {
        setState(() {
          isSuccess = true;
        });
      } else {
        AppSnackBar.error(context, 'Failed to update password. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // AnimatedSwitcher makes the transition between the form and success look incredibly smooth
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          // If isSuccess is true, show Success UI. Otherwise, show Form UI.
          child: isSuccess ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  // THE PASSWORD FORM Originally Screen 3
  Widget _buildFormView() {
    return SingleChildScrollView(
      key: const ValueKey('form_view'),
      // Keys are needed for AnimatedSwitcher to work
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            _buildSmallIconBadge(),
            const SizedBox(height: 32),
            const Text(
              "Set New Password",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Create a new, strong password that you\nhaven't used before to secure your pet\nadoption account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            TextFormField(
              controller: newPasswordController,
              obscureText: obscureNewPassword,
              decoration: AppDecorations.outlineInputDecoration(
                hintText: "••••••••",
                labelText: 'New Password',
                prefixIcon: Icons.lock_outlined,
              ).copyWith(
                suffixIcon: AnimatedBuilder(
                  animation: newPasswordController,
                  builder: (context, _) => PasswordSuffix(
                    showCheck: _isNewPasswordValid,
                    isObscure: obscureNewPassword,
                    onToggleVisibility: () {
                      setState(() {
                        obscureNewPassword = !obscureNewPassword;
                      });
                    },
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter a new password";
                }
                if (value.length < 8) {
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
            const SizedBox(height: 24),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: AppDecorations.outlineInputDecoration(
                hintText: '••••••••',
                labelText: 'Confirm new Password',
                prefixIcon: Icons.verified_user_outlined,
              ).copyWith(
                suffixIcon: AnimatedBuilder(
                  animation: Listenable.merge([
                    newPasswordController,
                    confirmPasswordController,
                  ]),
                  builder: (context, _) => PasswordSuffix(
                    showCheck: _isConfirmPasswordValid,
                    isObscure: obscureConfirmPassword,
                    onToggleVisibility: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please confirm your password";
                }
                if (value != newPasswordController.text) {
                  return "Password do not match";
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: loading ? null : updatePassword,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loading ? "Updating..." : "Update Password",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (!loading) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, color: Colors.white, size: 20),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Back button
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
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Back",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // THE SUCCESS SCREEN Originally Screen 4
  Widget _buildSuccessView() {
    return Padding(
      key: const ValueKey('success_view'), // Key for AnimatedSwitcher
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _buildBigSuccessIcon(),
          const SizedBox(height: 40),
          const Text(
            "Password Reset\nSuccessful!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Great news! Your password has been\nupdated. You can now log in with your new\ncredentials.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(),

          // Final Back to Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // Clear the navigation stack and go to Login
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Back to Login",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.login, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSmallIconBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset('assets/images/lock.png', height: 100, width: 100),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 3),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 16,
              color: Color(0xFF12B76A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBigSuccessIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF2E82F4).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.pets, size: 50, color: Color(0xFF2E82F4)),
          ),
        ),
        // Image.asset('assets/images/registerLogo.png', height: 100, width: 100),
        Positioned(
          bottom: 25,
          right: 25,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF12B76A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.check, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
