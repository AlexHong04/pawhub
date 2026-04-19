import 'dart:ui';

import 'package:flutter/material.dart';

class AppColors {
  // --- brand colors ---
  static const Color primary = Color(0xFF2B85EC);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // --- background and surfaces ---
  // Main scaffold background
  static const Color background = Color(0xFFF6F7F8);
  // Fill color for borderless inputs
  static const Color inputFill = Color(0xFFF5F7FA);
  // Standard white
  static const Color white = Color(0xFFFFFFFF);

  // --- Typography ---
  static const Color textPrimary = Color(0xFF0F172A); // primary text
  static const Color textBody = Color(0xFF334155); // Standard body text
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textPlaceholder = Color(0xFF94A3B8); // Placeholder
  static const Color textDark = Color(0xFF1D2331); // Main headings
  static const Color textLight = Color(0xFF8692A6); // Subtitles and secondary text
  static const Color borderGray = Color(0xFFE0E5EC);

  // --- Icons & Borders ---
  static const Color iconColor = Color(0xFF98A2B3); // Icons inside text fields
  static const Color border = Color(0xFFE2E8F0); // Outline borders and dividers

  // --- Role Badge Colors ---
  // Admin badge
  static const Color adminBadgeBg = Color(0xFFD1E9FF);
  static const Color adminBadgeText = Color(0xFF026AA2);

  // Volunteer badge
  static const Color volunteerBadgeBg = Color(0xFFF4EBFF);
  static const Color volunteerBadgeText = Color(0xFF6941C6);

  // Default/User badge
  static const Color defaultBadgeBg = Color(0xFFF2F4F7);
  static const Color defaultBadgeText = Color(0xFF344054);

  // --- Avatar & Status Colors ---
  static const Color errorRed = Color(0xFFD92D20); // Avatar initials fallback color

  // --- Dashboard Colors ---
  // Backgrounds
  static const Color dashboardBackground = Color(0xFFF9FAFB);
  static const Color chartBackground = defaultBadgeBg;

  // Dashboard text & headings
  static const Color dashboardHeading = Color(0xFF101828);
  static const Color dashboardSubtitle = Color(0xFF667085);
  static const Color dashboardHint = iconColor;

  // Chart colors
  static const Color chartBlue = Color(0xFF539DF8);
  static const Color dashboardBlue = Color(0xFF2E82F4);

  // Status colors
  static const Color successBg = Color(0xFFE6F4EA);
  static const Color successText = Color(0xFF12B76A);
  static const Color errorBg = Color(0xFFFCE8E8);
  static const Color errorText = Color(0xFFF04438);

  // Neutral grays (Dashboard)
  static const Color dashboardBorder = borderGray;
}
