import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:pawhub/core/constants/colors.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  // Focus nodes for automatic jumping
  final focus1 = FocusNode();
  final focus2 = FocusNode();
  final focus3 = FocusNode();
  final focus4 = FocusNode();

  final ctrl1 = TextEditingController();
  final ctrl2 = TextEditingController();
  final ctrl3 = TextEditingController();
  final ctrl4 = TextEditingController();

  bool loading = false;

  void verifyOtp() {
    setState(() => loading = true);
    // Simulate verification
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => loading = false);
        // Navigate to Reset Password Screen
        Navigator.pushNamed(context, '/set_new_password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: "Enter the 4-digit code sent to your email\n",
                      ),
                      TextSpan(
                        text: "user@example.com",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // OTP Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOtpBox(ctrl1, focus1, focus2),
                    _buildOtpBox(ctrl2, focus2, focus3),
                    _buildOtpBox(ctrl3, focus3, focus4),
                    _buildOtpBox(ctrl4, focus4, null),
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
                ElevatedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "Back",
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
        // Container(
        //   width: 100,
        //   height: 100,
        //   decoration: BoxDecoration(
        //     color: const Color(0xFF2E82F4).withOpacity(0.08),
        //     shape: BoxShape.circle,
        //   ),
        //   child: const Icon(Icons.lock, size: 40, color: Color(0xFF2E82F4)),
        // ),
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
            ), // Success Green
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
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Max 1 digit per box
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: "", // Hides the "0/1" character counter
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
