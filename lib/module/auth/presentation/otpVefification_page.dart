import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';

import '../auth_routes.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // Focus nodes for automatic jumping (Now 6)
  final focus1 = FocusNode();
  final focus2 = FocusNode();
  final focus3 = FocusNode();
  final focus4 = FocusNode();
  final focus5 = FocusNode();
  final focus6 = FocusNode();

  // Controllers (Now 6)
  final ctrl1 = TextEditingController();
  final ctrl2 = TextEditingController();
  final ctrl3 = TextEditingController();
  final ctrl4 = TextEditingController();
  final ctrl5 = TextEditingController();
  final ctrl6 = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    focus1.dispose(); focus2.dispose(); focus3.dispose();
    focus4.dispose(); focus5.dispose(); focus6.dispose();
    ctrl1.dispose(); ctrl2.dispose(); ctrl3.dispose();
    ctrl4.dispose(); ctrl5.dispose(); ctrl6.dispose();
    super.dispose();
  }

  void verifyOtp() async {
    final email = ModalRoute.of(context)!.settings.arguments as String;

    // Combine all 6 controllers
    final otpCode = ctrl1.text + ctrl2.text + ctrl3.text + ctrl4.text + ctrl5.text + ctrl6.text;

    // Check for 6 digits
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    setState(() => loading = true);

    bool success = await AuthService.verifyOtp(email, otpCode);

    if (mounted) {
      setState(() => loading = false);
      if (success) {
        Navigator.pushReplacementNamed(context, AuthRoutes.newPassword);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.lastError ?? 'Invalid OTP code. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grab the email safely for the UI
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? "your email";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with Check Badge
                _buildIconBadge(),
                const SizedBox(height: 32),

                const Text(
                  "OTP Verification",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: "Enter the 6-digit code sent to your email\n",
                      ),
                      TextSpan(
                        text: email, // Dynamic email display!
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // OTP Input Boxes (Now 6)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOtpBox(ctrl1, focus1, focus2),
                    _buildOtpBox(ctrl2, focus2, focus3),
                    _buildOtpBox(ctrl3, focus3, focus4),
                    _buildOtpBox(ctrl4, focus4, focus5),
                    _buildOtpBox(ctrl5, focus5, focus6),
                    _buildOtpBox(ctrl6, focus6, null), // Last one has no nextFocus
                  ],
                ),
                const SizedBox(height: 32),

                // Resend Code
                Column(
                  children: [
                    const Text(
                      "Didn't receive the code?",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        "Resend Code",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Verify Button
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
                    onPressed: loading ? null : verifyOtp,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loading ? "Verifying..." : "Verify",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!loading) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Back Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
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
              border: Border.all(color: AppColors.borderGray, width: 3),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 20,
              color: Color(0xFF12B76A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(
      TextEditingController controller,
      FocusNode currentFocus,
      FocusNode? nextFocus,
      ) {
    return Container(
      // Reduced width and height from 68 to 48/56 so 6 boxes fit on screen!
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentFocus.hasFocus
              ? AppColors.primary
              : AppColors.borderGray,
          width: 2,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: currentFocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: "",
          ),
          onChanged: (value) {
            if (value.isNotEmpty && nextFocus != null) {
              nextFocus.requestFocus(); // Jump to next box
            }
          },
        ),
      ),
    );
  }
}