import 'package:flutter/material.dart';

import '../models/vec2.dart';

/// Scale-to-fit preview of a template being built: the outline rectangle
/// plus every round hole, each labeled with its diameter. mm-space is
/// math/Y-up (matching the rest of the app's DXF convention); the canvas is
/// screen Y-down, so points are flipped in Y before drawing.
class TemplateOutlinePainter extends CustomPainter {
  final double outlineWidth;
  final double outlineHeight;
  final double cornerRadius;
  final List<({Vec2 center, double diameter})> holes;

  const TemplateOutlinePainter({
    required this.outlineWidth,
    required this.outlineHeight,
    this.cornerRadius = 0,
    required this.holes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (outlineWidth <= 0 || outlineHeight <= 0) return;
    const margin = 32.0;
    final availableW = size.width - margin * 2;
    final availableH = size.height - margin * 2;
    if (availableW <= 0 || availableH <= 0) return;
    final scale = (availableW / outlineWidth < availableH / outlineHeight) ? availableW / outlineWidth : availableH / outlineHeight;
    final originX = (size.width - outlineWidth * scale) / 2;
    final originY = (size.height - outlineHeight * scale) / 2;

    Offset toPx(Vec2 p) => Offset(originX + p.x * scale, originY + (outlineHeight - p.y) * scale);

    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outlineRect = Rect.fromPoints(toPx(const Vec2(0, 0)), toPx(Vec2(outlineWidth, outlineHeight)));
    if (cornerRadius > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(outlineRect, Radius.circular(cornerRadius * scale)), outlinePaint);
    } else {
      canvas.drawRect(outlineRect, outlinePaint);
    }

    final holePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final hole in holes) {
      final center = toPx(hole.center);
      final radiusPx = hole.diameter / 2 * scale;
      canvas.drawCircle(center, radiusPx, holePaint);
      _drawLabel(canvas, '⌀${hole.diameter.toStringAsFixed(1)}', center + Offset(radiusPx + 4, -radiusPx - 4));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.black87, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant TemplateOutlinePainter oldDelegate) {
    return oldDelegate.outlineWidth != outlineWidth ||
        oldDelegate.outlineHeight != outlineHeight ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.holes != holes;
  }
}
