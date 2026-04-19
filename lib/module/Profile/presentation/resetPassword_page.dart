import 'package:flutter/material.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/core/widgets/password_suffix.dart';

import '../../../core/constants/colors.dart';
import '../../auth/service/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscureCurrentPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  bool loading = false;

  bool get _isNewPasswordValid {
    final value = newPasswordController.text;
    return value.isNotEmpty &&
        value.length >= 8 &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  bool get _isConfirmPasswordValid {
    final value = confirmPasswordController.text;
    return value.isNotEmpty && value == newPasswordController.text;
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void resetPassword() async {
    // Validate the text fields
    if (!formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      loading = true;
    });
    // Get the currently logged-in user's email
    final currentUser = AuthService.supabase.auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No authenticated user found.')),
      );
      return;
    }
    // Verify the "Current Password" by attempting a silent login
    final verifyOldPassword = await AuthService.login(
      currentUser.email!,
      currentPasswordController.text.trim(),
      persistLocal: false,
      syncDatabase: false,
    );
    if (verifyOldPassword == null) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current password is incorrect!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Stop here if the old password is wrong
    }
    // If old password is correct, update to the New Password
    bool success = await AuthService.updatePassword(newPasswordController.text.trim());
    if (mounted) {
      setState(() {
        loading = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update password. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.iconColor),
        ),
        title: const Text(
          "Reset Password",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderGray, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "RESET PASSWORD",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Image.asset('assets/images/overlayLock.png', height: 100),
                    const SizedBox(height: 24),
                    const Text(
                      "Change Password",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "your new password must be different from previously used passwords.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          AppDecorations.outlineInputDecoration(
                            hintText: "••••••••",
                            labelText: 'Current Password',
                            prefixIcon: Icons.vpn_key_off_outlined,
                          ).copyWith(
                            suffixIcon: PasswordSuffix(
                              showCheck: false,
                              isObscure: obscureCurrentPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  obscureCurrentPassword =
                                      !obscureCurrentPassword;
                                });
                              },
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter current password";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          AppDecorations.outlineInputDecoration(
                            hintText: "••••••••",
                            labelText: 'New Password',
                            prefixIcon: Icons.lock_outlined,
                          ).copyWith(
                            suffixIcon: PasswordSuffix(
                              showCheck: _isNewPasswordValid,
                              isObscure: obscureNewPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  obscureNewPassword = !obscureNewPassword;
                                });
                              },
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
                      onChanged: (_) => setState(() {}),
                      decoration:
                          AppDecorations.outlineInputDecoration(
                            hintText: '••••••••',
                            labelText: 'Confirm new Password',
                            prefixIcon: Icons.verified_user_outlined,
                          ).copyWith(
                            suffixIcon: PasswordSuffix(
                              showCheck: _isConfirmPasswordValid,
                              isObscure: obscureConfirmPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  obscureConfirmPassword = !obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                      validator: (value) {
                        if (value != newPasswordController.text) {
                          return "Password do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: loading ? null : resetPassword,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              loading ? "Updating..." : "Reset Password",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                          }
                        },
                        child: const Text(
                          "Cancel",
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
            ),
          ),
        ),
      ),
    );
  }

}
