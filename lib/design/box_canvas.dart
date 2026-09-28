import 'package:flutter/material.dart';

import '../geometry/placed_entities.dart';
import '../geometry/tessellate.dart';
import '../models/palette_drag_item.dart';
import '../models/vec2.dart';
import 'box_painter.dart';
import 'design_controller.dart';
import 'snap.dart';

const double pixelsPerMm = 4.0;

/// Room shown around the box (mm), matching how far items may hang off it.
const double _marginMm = DesignController.overhangMm;

/// The interactive design surface: renders the box + placed templates +
/// holes, supports drag to move any item, and accepting templates/hole
/// presets dropped from the palette.
class BoxCanvas extends StatefulWidget {
  final DesignController controller;

  /// Reclaimed on every canvas interaction so keyboard shortcuts (copy,
  /// paste, delete) keep working after a property-panel text field was
  /// focused -- unfocusing that field doesn't hand focus back to this
  /// screen's shortcut handler on its own.
  final FocusNode? focusNode;

  const BoxCanvas({super.key, required this.controller, this.focusNode});

  @override
  State<BoxCanvas> createState() => _BoxCanvasState();
}

class _BoxCanvasState extends State<BoxCanvas> {
  final GlobalKey _contentKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  String? _draggingId;

  /// The item's true drag target, tracked independently of the clamped
  /// position the controller actually stores. Plate crossing on a dual-layer
  /// box relies on this: [DesignController.movePlacedTemplate] pins the
  /// stored position to the plate the item started on (no overhang between
  /// plates), so accumulating deltas onto that stored position would cancel
  /// out every tick and the item could never reach the other plate. Tracking
  /// the raw target here lets it keep moving even while the visible item
  /// stays pinned at the boundary, until it's far enough across for the
  /// controller to reassign it to the other plate.
  Vec2? _dragRawPosition;

  /// True while a background drag is panning the view.
  bool _panning = false;

  /// Ends any drag. Also runs when a gesture is cancelled or the pointer
  /// leaves the canvas (e.g. off the window), where no pointer-up may ever
  /// arrive: without it the item or the whole view would stay "on" and keep
  /// following the mouse.
  void _endDrags() {
    _draggingId = null;
    _dragRawPosition = null;
    _panning = false;
  }

  Vec2? _currentPosition(String id) {
    for (final p in controller.project.placedTemplates) {
      if (p.id == id) return p.position;
    }
    for (final h in controller.project.holes) {
      if (h.id == id) return h.position;
    }
    return null;
  }

  DesignController get controller => widget.controller;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Pans the view by [delta], which is expressed in the same (untransformed)
  /// content-pixel space as the drag events below -- InteractiveViewer's
  /// descendants already receive pointer deltas with the current zoom
  /// divided out, so applying the raw delta here lands 1:1 with screen
  /// movement at any zoom level, matching how the built-in pan gesture (kept
  /// off below, see [panEnabled]) would move things.
  void _panBy(Offset delta) {
    _transformationController.value = _transformationController.value.clone()
      ..translateByDouble(delta.dx, delta.dy, 0, 1);
  }

  Vec2 _localPxToMm(Offset localPx, double boxHeightMm) {
    return Vec2(
      localPx.dx / pixelsPerMm - _marginMm,
      boxHeightMm + _marginMm - localPx.dy / pixelsPerMm,
    );
  }

  Rect _mmBoxToScreenRect(BoundingBox boundingBox, double boxHeightMm) {
    final p1 = Offset(
      (boundingBox.minX + _marginMm) * pixelsPerMm,
      (boxHeightMm + _marginMm - boundingBox.maxY) * pixelsPerMm,
    );
    final p2 = Offset(
      (boundingBox.maxX + _marginMm) * pixelsPerMm,
      (boxHeightMm + _marginMm - boundingBox.minY) * pixelsPerMm,
    );
    return Rect.fromPoints(p1, p2).inflate(4);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final project = controller.project;
        final boxHeightMm = project.boxHeight;
        final contentWidth = (project.boxWidth + 2 * _marginMm) * pixelsPerMm;
        final contentHeight = (project.boxHeight + 2 * _marginMm) * pixelsPerMm;

        // Each item's hit area is its full (opaque) bounding-box rectangle,
        // so a small item nested entirely inside a larger one's rectangle
        // (e.g. a screw hole sitting on top of a placed template) needs to
        // be on top for hit-testing or a tap/drag there can only ever reach
        // the larger item underneath. A Stack hit-tests its children back
        // to front (last child wins first), so sorting largest-area-first
        // here -- smallest added last -- puts every smaller item above
        // anything it's nested inside, regardless of placement order.
        final itemRects = <(String id, Rect rect)>[
          for (final placed in project.placedTemplates)
            if (controller.library.byId(placed.templateId) case final template?)
              (placed.id, _mmBoxToScreenRect(entitiesBoundingBox(placedTemplateEntities(template, placed)), boxHeightMm)),
          for (final hole in project.holes) (hole.id, _mmBoxToScreenRect(hole.boundingBox, boxHeightMm)),
        ]..sort((a, b) => (b.$2.width * b.$2.height).compareTo(a.$2.width * a.$2.height));
        final itemOverlays = [for (final (id, rect) in itemRects) _dragHandle(rect, id, boxHeightMm)];

        return MouseRegion(
          onExit: (_) => _endDrags(),
          child: Listener(
          // Purely an observer -- doesn't join the gesture arena, so it
          // can't steal drags/pans from the detectors below.
          onPointerDown: (_) => widget.focusNode?.requestFocus(),
          child: DragTarget<PaletteDragItem>(
            onAcceptWithDetails: (details) {
              final box =
                  _contentKey.currentContext!.findRenderObject() as RenderBox;
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
                transformationController: _transformationController,
                // Panning is handled manually by the background GestureDetector
                // below instead of InteractiveViewer's own pan gesture, so it
                // never competes with the per-item drag handles for the arena.
                panEnabled: false,
                scaleEnabled: true,
                minScale: 0.25,
                maxScale: 8,
                constrained: false,
                // A finite margin makes InteractiveViewer stop zooming out
                // once content + margin would no longer fill the viewport,
                // which for a small box is well above minScale.
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  key: _contentKey,
                  width: contentWidth,
                  height: contentHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: DesignPainter(
                            controller,
                            pixelsPerMm: pixelsPerMm,
                            marginMm: _marginMm,
                            isDark: Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => controller.select(null),
                          onPanStart: (_) => _panning = true,
                          onPanUpdate: (details) {
                            if (_panning) _panBy(details.delta);
                          },
                          onPanEnd: (_) => _endDrags(),
                          onPanCancel: _endDrags,
                        ),
                      ),
                      ...itemOverlays,
                      if (controller.measureModeEnabled)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => controller.placeMeasurePoint(
                              snapPoint(
                                _localPxToMm(
                                  details.localPosition,
                                  boxHeightMm,
                                ),
                                controller,
                              ),
                            ),
                            onPanStart: (details) => controller.startMeasure(
                              snapPoint(
                                _localPxToMm(
                                  details.localPosition,
                                  boxHeightMm,
                                ),
                                controller,
                              ),
                            ),
                            onPanUpdate: (details) => controller.updateMeasure(
                              snapPoint(
                                _localPxToMm(
                                  details.localPosition,
                                  boxHeightMm,
                                ),
                                controller,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          ),
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
          _dragRawPosition = _currentPosition(id);
          controller.select(id);
        },
        onPanUpdate: (details) {
          if (_draggingId != id) return;
          final deltaMm = Vec2(
            details.delta.dx / pixelsPerMm,
            -details.delta.dy / pixelsPerMm,
          );
          final raw = (_dragRawPosition ?? _currentPosition(id))?.add(deltaMm);
          if (raw == null) return;
          _dragRawPosition = raw;
          _moveItem(id, raw);
        },
        onPanEnd: (_) {
          _draggingId = null;
          _dragRawPosition = null;
        },
        onPanCancel: () {
          if (_draggingId == id) _draggingId = null;
          _dragRawPosition = null;
        },
        onTap: () => controller.select(id),
      ),
    );
  }

  void _moveItem(String id, Vec2 rawPosition) {
    final snapped = controller.snapToGrid(rawPosition);
    for (final p in controller.project.placedTemplates) {
      if (p.id == id) {
        controller.movePlacedTemplate(id, snapped);
        return;
      }
    }
    for (final h in controller.project.holes) {
      if (h.id == id) {
        controller.updateHole(id, (hole) => hole.copyWith(position: snapped));
        return;
      }
    }
  }
}
