import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
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
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void register() {
    // check if the form is valid before processing
    if (formKey.currentState!.validate()) {
      setState(() {
        loading = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing Registration...')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // appBar: AppBar(
      //   title: const Text(
      //     "Register",
      //     style: TextStyle(
      //       fontWeight: FontWeight.bold,
      //       color: AppColors.textBody, // Changes the text color
      //     ),
      //   ),
      //   elevation: 0,
      //   centerTitle: true,
      //   backgroundColor: AppColors.background,
      //   iconTheme: const IconThemeData(
      //     color: AppColors.textBody, // Ensures the back button arrow matches the text color
      //   ),
      // ),
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
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.iconColor,
                                    ),
                                    onPressed: () {
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscurePassword,
                            decoration:
                                AppDecorations.outlineInputDecoration(
                                  hintText: "••••••••",
                                  prefixIcon: Icons.verified_user_outlined,
                                  labelText: "Confirm Password",
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.iconColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        obscurePassword = !obscurePassword;
                                      });
                                    },
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
                            // decoration: BoxDecoration(
                            //   boxShadow: [
                            //     BoxShadow(
                            //       color: AppColors.primary,
                            //       blurRadius: 12,
                            //       offset: const Offset(0, 4),
                            //     ),
                            //   ],
                            // ),
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

//   Widget _buildTextField({
//     required TextEditingController Controller,
//     required String hintText,
//     required IconData prefixIcon,
//     bool obscureText = false,
//     TextInputType keyboardType = TextInputType.text,
//     Widget? suffixIcon,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//         controller: Controller,
//         obscureText: obscureText,
//         keyboardType: keyboardType,
//         validator: validator,
//         style: TextStyle(color: AppColors.textDark, fontSize: 16),
//         decoration: InputDecoration(
//           hintText: hintText,
//           hintStyle: TextStyle(color: AppColors.textLight),
//           prefixIcon: Icon(prefixIcon, color: AppColors.textLight),
//           suffix: suffixIcon,
//           filled: true,
//           fillColor: AppColors.white,
//           contentPadding: const EdgeInsets.symmetric(vertical: 16),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide(color: AppColors.borderGray),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide(color: AppColors.borderGray),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide(color: AppColors.primaryLight),
//           ),
//         )
//     );
//   }
// }
