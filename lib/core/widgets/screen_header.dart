import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';

// Wide title + one line of context, as on the admin panel's pages
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ScreenHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.display),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppType.style(size: 16, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    );
  }
}
