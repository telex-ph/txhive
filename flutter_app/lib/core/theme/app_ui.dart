import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppUI {
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 14;

  static BorderRadius get brXs => BorderRadius.circular(radiusXs);
  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);
  static BorderRadius get brXl => BorderRadius.circular(radiusXl);

  static List<BoxShadow> get panelShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static InputDecoration inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textSoft,
        fontSize: 14,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: brMd,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: brMd,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: brMd,
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.2,
        ),
      ),
    );
  }
}
