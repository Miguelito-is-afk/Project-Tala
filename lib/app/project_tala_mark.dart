import 'dart:math';

import 'package:flutter/material.dart';

import 'branding.dart';

class ProjectTalaMark extends StatelessWidget {
  const ProjectTalaMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(
          fillColor: colors.primary,
          accentColor: talaGold,
          strokeColor: colors.surface,
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.fillColor,
    required this.accentColor,
    required this.strokeColor,
  });

  final Color fillColor;
  final Color accentColor;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.44;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;

    final inner = radius * 0.52;
    final points = <Offset>[];
    for (var index = 0; index < 8; index++) {
      final angle =
          -90 * (3.141592653589793 / 180) + (index * (3.141592653589793 / 4));
      final currentRadius = index.isEven ? radius : inner;
      final x = center.dx + currentRadius * cos(angle);
      final y = center.dy + currentRadius * sin(angle);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      path.lineTo(points[index].dx, points[index].dy);
    }
    path.close();
    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withValues(alpha: 0.9);
    final glowRadius = radius * 0.16;
    canvas.drawCircle(center, glowRadius, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..color = strokeColor;
    canvas.drawCircle(center, radius * 0.84, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
