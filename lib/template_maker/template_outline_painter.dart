import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dxf_entity.dart';
import '../models/vec2.dart';
import 'template_maker_controller.dart';

/// Scale-to-fit preview of a template being built: the outline rectangle
/// (optionally corner-filleted, corner-chamfered, or corner-notched) plus
/// every hole, round or slot, each labeled with its size. mm-space is
/// math/Y-up (matching the rest of the app's DXF convention); the canvas is
/// screen Y-down, so points are flipped in Y before drawing.
class TemplateOutlinePainter extends CustomPainter {
  final double outlineWidth;
  final double outlineHeight;
  final TemplateMakerCornerStyle cornerStyle;
  final double cornerSize;
  final List<
      ({
        TemplateMakerHoleShape shape,
        Vec2 center,
        double diameter,
        double slotLength,
        double slotWidth,
        double rotationDeg,
      })> holes;

  const TemplateOutlinePainter({
    required this.outlineWidth,
    required this.outlineHeight,
    this.cornerStyle = TemplateMakerCornerStyle.fillet,
    this.cornerSize = 0,
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
    final cornerAmount = cornerSize <= 0 ? 0.0 : math.min(cornerSize, math.min(outlineWidth, outlineHeight) / 2);
    if (cornerAmount <= 0) {
      canvas.drawRect(Rect.fromPoints(toPx(const Vec2(0, 0)), toPx(Vec2(outlineWidth, outlineHeight))), outlinePaint);
    } else if (cornerStyle == TemplateMakerCornerStyle.fillet) {
      final outlineRect = Rect.fromPoints(toPx(const Vec2(0, 0)), toPx(Vec2(outlineWidth, outlineHeight)));
      canvas.drawRRect(RRect.fromRectAndRadius(outlineRect, Radius.circular(cornerAmount * scale)), outlinePaint);
    } else {
      final vertices = cornerStyle == TemplateMakerCornerStyle.chamfer
          ? chamferedRectVertices(outlineWidth, outlineHeight, cornerAmount)
          : notchedRectVertices(outlineWidth, outlineHeight, cornerAmount);
      final pts = vertices.map((v) => toPx(v.point)).toList();
      canvas.drawPath(Path()..addPolygon(pts, true), outlinePaint);
    }

    final holePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final hole in holes) {
      if (hole.shape == TemplateMakerHoleShape.round) {
        final center = toPx(hole.center);
        final radiusPx = hole.diameter / 2 * scale;
        canvas.drawCircle(center, radiusPx, holePaint);
        _drawLabel(canvas, '⌀${hole.diameter.toStringAsFixed(1)}', center + Offset(radiusPx + 4, -radiusPx - 4));
      } else {
        final outline = DxfPolyline(stadiumVertices(hole.slotLength, hole.slotWidth), closed: true)
            .transformed(delta: hole.center, rotationDeg: hole.rotationDeg);
        final pts = outline.toPoints().map(toPx).toList();
        canvas.drawPath(Path()..addPolygon(pts, true), holePaint);
        final center = toPx(hole.center);
        _drawLabel(canvas, '${hole.slotLength.toStringAsFixed(1)}x${hole.slotWidth.toStringAsFixed(1)}', center + const Offset(6, -6));
      }
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
        oldDelegate.cornerStyle != cornerStyle ||
        oldDelegate.cornerSize != cornerSize ||
        oldDelegate.holes != holes;
  }
}
