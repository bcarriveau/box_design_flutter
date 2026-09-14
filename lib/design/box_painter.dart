import 'package:flutter/material.dart';

import '../geometry/transform.dart';
import '../models/box_project.dart';
import '../models/dxf_entity.dart';
import '../models/vec2.dart';
import 'design_controller.dart';

/// Paints a [BoxProject] at [pixelsPerMm] scale. The canvas itself uses
/// screen (Y-down) pixels, so every mm-space point is flipped in Y before
/// drawing (mm-space is math/Y-up, matching DXF convention).
class DesignPainter extends CustomPainter {
  final DesignController controller;
  final double pixelsPerMm;

  DesignPainter(this.controller, {required this.pixelsPerMm}) : super(repaint: controller);

  Offset _toPx(Vec2 p, double boxHeightMm) => Offset(p.x * pixelsPerMm, (boxHeightMm - p.y) * pixelsPerMm);

  @override
  void paint(Canvas canvas, Size size) {
    final project = controller.project;
    final boxHeightMm = project.boxHeight;

    _drawGrid(canvas, project, boxHeightMm);
    _drawEntities(canvas, project.boxOutline, boxHeightMm, color: Colors.black, width: 2);

    for (final placed in project.placedTemplates) {
      final template = controller.library.byId(placed.templateId);
      if (template == null) continue;
      final entities = placeEntities(template.entities, delta: placed.position, rotationDeg: placed.rotationDeg);
      final selected = controller.selectedId == placed.id;
      _drawEntities(canvas, entities, boxHeightMm, color: selected ? Colors.blue : Colors.black87, width: selected ? 1.6 : 1.0);
    }

    for (final hole in project.holes) {
      final selected = controller.selectedId == hole.id;
      _drawEntities(canvas, hole.toEntities(), boxHeightMm, color: selected ? Colors.blue : Colors.red, width: selected ? 1.6 : 1.0);
    }
  }

  void _drawGrid(Canvas canvas, BoxProject project, double boxHeightMm) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    const step = 10.0;
    for (double x = 0; x <= project.boxWidth; x += step) {
      canvas.drawLine(_toPx(Vec2(x, 0), boxHeightMm), _toPx(Vec2(x, project.boxHeight), boxHeightMm), paint);
    }
    for (double y = 0; y <= project.boxHeight; y += step) {
      canvas.drawLine(_toPx(Vec2(0, y), boxHeightMm), _toPx(Vec2(project.boxWidth, y), boxHeightMm), paint);
    }
  }

  void _drawEntities(
    Canvas canvas,
    List<DxfEntity> entities,
    double boxHeightMm, {
    required Color color,
    required double width,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final entity in entities) {
      final points = entity.toPoints();
      if (points.isEmpty) continue;
      final start = _toPx(points.first, boxHeightMm);
      final path = Path()..moveTo(start.dx, start.dy);
      for (final p in points.skip(1)) {
        final px = _toPx(p, boxHeightMm);
        path.lineTo(px.dx, px.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DesignPainter oldDelegate) => true;
}
