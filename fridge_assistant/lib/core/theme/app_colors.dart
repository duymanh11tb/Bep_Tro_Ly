import 'package:flutter/material.dart';

/// Định nghĩa màu sắc chính cho ứng dụng Bếp Trợ Lý
class AppColors {
  AppColors._();

  // Primary Colors - Green theme
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primarySurface = Color(0xFFF1F8E9);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Input Field Colors
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color inputBorderFocused = primary;
  static const Color inputBackground = Color(0xFFF9FAFB);
  static const Color inputLabel = Color(0xFF374151);

  // Background Colors
  static const Color background = Colors.white;
  static const Color backgroundSecondary = Color(0xFFF3F4F6);

  // Status Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Other
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
}
