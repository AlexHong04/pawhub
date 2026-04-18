import 'package:flutter/material.dart';

import 'appDecorations.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: AppDecorations.outlineInputDecoration(
          hintText: hint,
          labelText: label,
          prefixIcon: icon,
        ),
      ),
    );
  }
}