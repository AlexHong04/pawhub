
import 'package:flutter/material.dart';

import 'appDecorations.dart';

class CustomDropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: AppDecorations.outlineInputDecoration(
          hintText: 'Select $label',
          labelText: label,
          prefixIcon: icon,
        ),
        items: items
            .map(
              (val) => DropdownMenuItem(
            value: val,
            child: Text(val, style: const TextStyle(fontSize: 14)),
          ),
        )
            .toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

