import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';

class PasswordSuffix extends StatelessWidget {
  final bool showCheck;
  final bool isObscure;
  final VoidCallback onToggleVisibility;
  final double width;

  const PasswordSuffix({
    super.key,
    required this.showCheck,
    required this.isObscure,
    required this.onToggleVisibility,
    this.width = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheck)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.check_circle,
                color: Color(0xFF06B6D4),
                size: 20,
              ),
            ),
          IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.iconColor,
            ),
            onPressed: onToggleVisibility,
          ),
        ],
      ),
    );
  }
}

