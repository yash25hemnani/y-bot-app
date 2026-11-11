import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';

// Type system, shared with the admin panel.
// Saira is one variable font with weight and width axes. Width carries the
// personality: wide for titles and device names, like lettering on a control
// panel; normal width for reading. Both axes are set explicitly, because a
// variable font doesn't pick up FontWeight on its own on every platform.
class AppType {
  AppType._();

  static const String family = 'Saira';

  static const double normal = 100;
  static const double semiWide = 112;
  static const double wide = 125;

  static TextStyle style({
    required double size,
    double weight = 400,
    double width = normal,
    double? height,
    double? letterSpacing,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation('wght', weight), FontVariation('wdth', width)],
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static FontWeight _weight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  // Screen titles: wide and tight, the app's one loud typographic move
  static final TextStyle display = style(size: 32, weight: 600, width: wide, height: 1.05, letterSpacing: -0.6);

  // Device names in rows
  static final TextStyle name = style(size: 20, weight: 600, width: wide, height: 1.2, letterSpacing: -0.2);

  // Section headings ("Nearby", "Controls")
  static final TextStyle section = style(size: 18, weight: 600, width: semiWide, height: 1.25);
}
