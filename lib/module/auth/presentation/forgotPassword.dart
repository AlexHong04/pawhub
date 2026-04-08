import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool loading = false;

  void sendResetCode() async {
    if (emailController.text.isEmpty || !emailController.text.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }
    setState(() => loading = true);

    bool sent = await AuthService.sendOtp(emailController.text.trim());

    if (mounted) {
      setState(() => loading = false);
      if (sent) {
        Navigator.pushNamed(
          context,
          '/otp_verification',
          arguments: emailController.text.trim(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP. Try again')),
        );
      }
    }
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
                // Icon with Badge
                _buildIconBadge(
                  mainIcon: Icons.restore,
                  badgeIcon: Icons.vpn_key,
                  badgeColor: const Color(0xFFF79009), // Warning Yellow
                ),
                const SizedBox(height: 32),
                // Headings
                const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Don't worry! It happens. Please enter the\nemail address linked with your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                // Email Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "EMAIL ADDRESS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: AppDecorations.outlineInputDecoration(
                        hintText: "Enter your email",
                        labelText: "you@example.com",
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Action Button
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
                    onPressed: loading ? null : sendResetCode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loading ? "Sending..." : "Send Reset Code",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!loading) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
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
                    }else{
                      Navigator.pushReplacementNamed(context, '/login');
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

  // Reusable Helper for the circular icon with a badge
  Widget _buildIconBadge({
    required IconData mainIcon,
    required IconData badgeIcon,
    required Color badgeColor,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset('assets/images/overlayLock.png', height: 100, width: 100),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF9FAFB), width: 3),
            ),
            child: Icon(badgeIcon, size: 16, color: badgeColor),
          ),
        ),
      ],
    );
  }
}
