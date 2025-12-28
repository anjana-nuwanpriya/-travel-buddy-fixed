import 'package:flutter/material.dart';

class AppColors {
  // Primary Orange Theme
  static const Color primary = Color(0xFFFF6B35); // Vibrant Orange
  static const Color primaryDark = Color(0xFFE5501E); // Dark Orange
  static const Color primaryLight = Color(0xFFFF8C61); // Light Orange

  // Accent & Status Colors
  static const Color accent = Color(0xFFFF9F66);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFF44336);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);

  // Message Colors
  static const Color messageSent = Color(
    0xFFFF6B35,
  ); // Orange for sent messages
  static const Color messageReceived = Color(
    0xFFF5F5F5,
  ); // Light gray for received messages
  static const Color messageUnread = Color(
    0xFFFFE5DC,
  ); // Light orange tint for unread conversations
}
