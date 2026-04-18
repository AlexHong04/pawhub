import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';

class CustomSearchField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;
  final String labelText;

  const CustomSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search...',
    this.labelText = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 8),
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, TextEditingValue value, _) {
          return TextFormField(
            controller: controller,
            onChanged: onChanged,
            decoration:
                AppDecorations.roundedSearchDecoration(
                  hintText: hintText,
                  labelText: labelText,
                  prefixIcon: Icons.search,
                )
          );
        },
      ),
    );
  }
}
