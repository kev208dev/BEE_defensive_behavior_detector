/// Design tokens.
///
/// **This file, together with `lib/core/widgets/`, is the Figma swap point.**
/// When the designer's Figma file arrives, the values here are replaced with
/// the exported design tokens and the shared components are restyled. Nothing
/// in `domain/`, `data/` or any service reads from this file, so no business
/// logic changes when the design does.
///
/// Screens must never hard-code a colour, font size, padding or radius —
/// always reach for a token, so a redesign is a single-file edit.
library;

import 'package:flutter/material.dart';



/// Semantic colour palette.
abstract final class AppColors {
  // --- Brand ---
  static const Color primary = Color(0xFFF5A524);
  static const Color primaryDark = Color(0xFFC2800E);
  static const Color onPrimary = Color(0xFF1A1206);

  // --- Surfaces ---
  static const Color background = Color(0xFF12100D);
  static const Color surface = Color(0xFF1C1915);
  static const Color surfaceVariant = Color(0xFF262119);
  static const Color outline = Color(0xFF3A342A);

  // --- Text ---
  static const Color textPrimary = Color(0xFFF5F0E6);
  static const Color textSecondary = Color(0xFFB3AA98);
  static const Color textDisabled = Color(0xFF6E6759);

  // --- Hive status. The single source of truth for status colour. ---
  static const Color statusNormal = Color(0xFF3FB950);
  static const Color statusCaution = Color(0xFFF0A92E);
  static const Color statusDanger = Color(0xFFE5484D);
  static const Color statusOffline = Color(0xFF6E7681);

  // --- Feedback ---
  static const Color success = statusNormal;
  static const Color warning = statusCaution;
  static const Color error = statusDanger;
}

/// Text styles, named by role rather than by size.
abstract final class AppTypography {
  static const String? fontFamily = null; // Figma will supply the family.

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.textPrimary,
  );
}

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(md);
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

/// Named durations, so animation timing is consistent and tunable.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
}
