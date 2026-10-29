import 'dart:math' as math;

import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../theme.dart';

/// Gradient surface with soft decorative orbs, used for hero areas.
class HeroSurface extends StatelessWidget {
  const HeroSurface({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.radius = 28});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            const PositionedDirectional(end: -60, top: -70, child: _Orb(size: 220, opacity: 0.16)),
            const PositionedDirectional(start: -40, bottom: -80, child: _Orb(size: 180, opacity: 0.10)),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Colors.white.withValues(alpha: opacity), Colors.white.withValues(alpha: 0)]),
    ),
  );
}

/// Circular progress with a gradient sweep and rounded cap.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.size, this.stroke = 16, this.child});

  final double value;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFE8EAF4);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, track),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.track);
  final double value;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    canvas.drawArc(inner, 0, math.pi * 2, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      // Gradient spans only the filled arc, so the head is always teal.
      ..shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        // Back to indigo after the head so the round start cap stays indigo.
        colors: const [AppColors.indigo, AppColors.violet, AppColors.teal, AppColors.teal, AppColors.indigo],
        stops: [0, value / 2, value, (value + 1) / 2, 1],
      ).createShader(rect);
    canvas.drawArc(inner, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.track != track;
}

/// Tinted rounded square behind an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = AppColors.indigo, this.size = 48});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.32)),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Battery pill; turns red when low and not charging.
class BatteryPill extends StatelessWidget {
  const BatteryPill({super.key, required this.label, required this.status, this.onDark = false});
  final String label;
  final PeerStatus? status;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final level = status?.batteryLevel;
    if (level == null) return const SizedBox.shrink();
    final low = status!.isLow;
    final fg = low ? AppColors.rose : (onDark ? Colors.white : Theme.of(context).colorScheme.onSurface);
    final bg = onDark
        ? Colors.white.withValues(alpha: 0.14)
        : (low ? AppColors.rose.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status!.charging == true ? Icons.bolt_rounded : (low ? Icons.battery_alert_rounded : Icons.battery_5_bar_rounded),
            size: 16,
            color: status!.charging == true ? AppColors.teal : fg,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label  ${ltr('$level%')}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
