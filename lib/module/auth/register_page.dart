import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';

import '../../core/constants/string.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void handleRegister() {
    if (formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing Registration...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: Center(
        // child: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //
        //       Text(
        //
        //       )
        //   ],
        // )
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  value!.contains('@') ? null : 'Enter a valid email';
                  return null;
                },
              ),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  value!.length < 6 ? null : 'Enter a valid password';
                  return null;
                },
              ),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != passwordController.text)
                    return 'Password do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: handleRegister,
                  child: const Text("Register"),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(AppStrings.login),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
