import 'package:flutter/cupertino.dart';

import '../constants/colors.dart';

class SpecificPassword {

  static Widget buildRequirementChip(String text, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isMet ? AppColors.primaryLight : AppColors.white,
        border: Border.all(color: isMet ? AppColors.primary : AppColors.border),
        borderRadius: BorderRadius.circular(20), // Pill shape
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isMet ? AppColors.primary : AppColors.textLight,
        ),
      ),
    );
  }
}