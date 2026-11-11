import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';

enum LampState { connected, connecting, idle, off }

// A device's connection light, matching the admin panel's lamp.
// Connected lamps glow and breathe slowly; idle ones are an unlit outline.
// Decorative: always pair it with text that says the same thing.
class StatusLamp extends StatefulWidget {
  final LampState state;
  final double size;

  const StatusLamp({super.key, required this.state, this.size = 14});

  @override
  State<StatusLamp> createState() => _StatusLampState();
}

class _StatusLampState extends State<StatusLamp> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(StatusLamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  // Only connected lamps pulse, and never when the system asks for less motion
  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.state == LampState.connected && !reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final Color? fill = switch (widget.state) {
      LampState.connected => AppColors.success,
      LampState.connecting => AppColors.warning,
      LampState.off => AppColors.error,
      LampState.idle => null,
    };

    final lamp = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: fill == null ? Border.all(color: AppColors.textDisabled, width: 2) : null,
        boxShadow: widget.state == LampState.connected
            ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.7), blurRadius: size * 0.7)]
            : null,
      ),
    );

    return SizedBox(
      width: size * 2,
      height: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.state == LampState.connected)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                return Opacity(
                  opacity: (1 - t) * 0.6,
                  child: Container(
                    width: size * (0.9 + t * 1.1),
                    height: size * (0.9 + t * 1.1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                  ),
                );
              },
            ),
          lamp,
        ],
      ),
    );
  }
}
