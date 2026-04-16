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
      padding: const EdgeInsets.all(16.0),
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, TextEditingValue value, _) {
          return TextFormField(
            controller: controller,
            onChanged: onChanged,
            decoration: AppDecorations.outlineInputDecoration(
              hintText: hintText,
              labelText: labelText,
              prefixIcon: Icons.search,
            ).copyWith(
              fillColor: AppColors.inputFill,
              filled: true,

              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
