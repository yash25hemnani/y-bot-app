import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';

class SegmentedNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const SegmentedNavItem({required this.icon, required this.selectedIcon, required this.label});
}

// Bottom navigation as one segmented pill, the same selector the admin panel
// uses in its top bar. The current section gets a raised segment and teal text.
class SegmentedNavBar extends StatelessWidget {
  final List<SegmentedNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SegmentedNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _Segment(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final SegmentedNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 48,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected ? AppColors.surfaceRaised : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? item.selectedIcon : item.icon, size: 20, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.style(size: 14, weight: 500, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
