import 'package:flutter/material.dart';

import '../geometry/tessellate.dart';
import '../geometry/transform.dart';
import '../models/palette_drag_item.dart';
import '../models/vec2.dart';
import 'box_painter.dart';
import 'design_controller.dart';

const double pixelsPerMm = 4.0;

/// The interactive design surface: renders the box + placed templates +
/// holes, supports drag to move any item, and accepting templates/hole
/// presets dropped from the palette.
class BoxCanvas extends StatefulWidget {
  final DesignController controller;

  const BoxCanvas({super.key, required this.controller});

  @override
  State<BoxCanvas> createState() => _BoxCanvasState();
}

class _BoxCanvasState extends State<BoxCanvas> {
  final GlobalKey _contentKey = GlobalKey();
  String? _draggingId;

  DesignController get controller => widget.controller;

  Vec2 _localPxToMm(Offset localPx, double boxHeightMm) {
    return Vec2(localPx.dx / pixelsPerMm, boxHeightMm - localPx.dy / pixelsPerMm);
  }

  Rect _mmBoxToScreenRect(BoundingBox boundingBox, double boxHeightMm) {
    final p1 = Offset(boundingBox.minX * pixelsPerMm, (boxHeightMm - boundingBox.maxY) * pixelsPerMm);
    final p2 = Offset(boundingBox.maxX * pixelsPerMm, (boxHeightMm - boundingBox.minY) * pixelsPerMm);
    return Rect.fromPoints(p1, p2).inflate(4);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final project = controller.project;
        final boxHeightMm = project.boxHeight;
        final contentWidth = project.boxWidth * pixelsPerMm;
        final contentHeight = project.boxHeight * pixelsPerMm;

        final itemOverlays = <Widget>[];
        for (final placed in project.placedTemplates) {
          final template = controller.library.byId(placed.templateId);
          if (template == null) continue;
          final entities = placeEntities(template.entities, delta: placed.position, rotationDeg: placed.rotationDeg);
          final rect = _mmBoxToScreenRect(entitiesBoundingBox(entities), boxHeightMm);
          itemOverlays.add(_dragHandle(rect, placed.id, boxHeightMm));
        }
        for (final hole in project.holes) {
          final rect = _mmBoxToScreenRect(hole.boundingBox, boxHeightMm);
          itemOverlays.add(_dragHandle(rect, hole.id, boxHeightMm));
        }

        return DragTarget<PaletteDragItem>(
          onAcceptWithDetails: (details) {
            final box = _contentKey.currentContext!.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.offset);
            final mm = _localPxToMm(local, boxHeightMm);
            switch (details.data) {
              case TemplateDragItem(templateId: final id):
                controller.addPlacedTemplate(id, mm);
              case HolePresetDragItem(preset: final preset):
                controller.addHoleFromPreset(preset, mm);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return InteractiveViewer(
              panEnabled: false,
              scaleEnabled: true,
              minScale: 0.25,
              maxScale: 8,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(400),
              child: SizedBox(
                key: _contentKey,
                width: contentWidth,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: DesignPainter(controller, pixelsPerMm: pixelsPerMm)),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => controller.select(null),
                      ),
                    ),
                    ...itemOverlays,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dragHandle(Rect rect, String id, double boxHeightMm) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _draggingId = id;
          controller.select(id);
        },
        onPanUpdate: (details) {
          if (_draggingId != id) return;
          final deltaMm = Vec2(details.delta.dx / pixelsPerMm, -details.delta.dy / pixelsPerMm);
          _moveItem(id, deltaMm);
        },
        onPanEnd: (_) => _draggingId = null,
        onTap: () => controller.select(id),
      ),
    );
  }

  void _moveItem(String id, Vec2 deltaMm) {
    for (final p in controller.project.placedTemplates) {
      if (p.id == id) {
        controller.movePlacedTemplate(id, p.position.add(deltaMm));
        return;
      }
    }
    for (final h in controller.project.holes) {
      if (h.id == id) {
        controller.updateHole(id, (hole) => hole.copyWith(position: hole.position.add(deltaMm)));
        return;
      }
    }
  }
}
