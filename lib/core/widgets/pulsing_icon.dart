import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';

// Icon in a circle with glow rings that pulse outward while [animate] is true
class PulsingIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool animate;
  final Color iconColor;
  final Color backgroundColor;
  final Color ringColor;
  final int ringCount;
  final double ringSpread;
  final Duration pulseDuration;
  final VoidCallback? onTap;

  const PulsingIcon({
    super.key,
    required this.icon,
    this.size = 112,
    this.animate = true,
    this.iconColor = AppColors.primary,
    this.backgroundColor = AppColors.surfaceRaised,
    this.ringColor = AppColors.primary,
    this.ringCount = 3,
    this.ringSpread = 0.6,
    this.pulseDuration = const Duration(milliseconds: 2400),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      animate: animate,
      glowColor: ringColor,
      glowCount: ringCount,
      glowRadiusFactor: ringSpread,
      duration: pulseDuration,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(
              color: ringColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: size * 0.45, color: iconColor),
        ),
      ),
    );
  }
}
