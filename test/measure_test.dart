import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/design/design_controller.dart';
import 'package:box_design_flutter/design/snap.dart';
import 'package:box_design_flutter/models/hole.dart';
import 'package:box_design_flutter/models/placed_template.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/services/template_library.dart';

void main() {
  test('toggling measure mode on then off clears any in-progress measurement', () {
    final controller = DesignController(TemplateLibrary());

    expect(controller.measureModeEnabled, isFalse);
    controller.toggleMeasureMode();
    expect(controller.measureModeEnabled, isTrue);

    controller.startMeasure(const Vec2(0, 0));
    controller.updateMeasure(const Vec2(30, 40));
    expect(controller.measureStart, const Vec2(0, 0));
    expect(controller.measureEnd, const Vec2(30, 40));

    controller.toggleMeasureMode();
    expect(controller.measureModeEnabled, isFalse);
    expect(controller.measureStart, isNull);
    expect(controller.measureEnd, isNull);
  });

  test('updateMeasure is a no-op until a measurement has been started', () {
    final controller = DesignController(TemplateLibrary());

    controller.updateMeasure(const Vec2(10, 10));
    expect(controller.measureEnd, isNull);

    controller.startMeasure(const Vec2(5, 5));
    controller.updateMeasure(const Vec2(35, 45));
    expect(controller.measureStart, const Vec2(5, 5));
    expect(controller.measureEnd, const Vec2(35, 45));
  });

  test('a 3-4-5 triangle scaled by 10 measures to exactly 50mm', () {
    final controller = DesignController(TemplateLibrary());
    controller.startMeasure(const Vec2(10, 10));
    controller.updateMeasure(const Vec2(40, 50));

    final delta = controller.measureEnd!.subtract(controller.measureStart!);
    final distance = (delta.x * delta.x + delta.y * delta.y);
    expect(distance, closeTo(2500, 1e-9)); // 50mm squared
  });

  test('click-to-measure: first click sets a point, second completes it, third starts fresh', () {
    final controller = DesignController(TemplateLibrary());

    controller.placeMeasurePoint(const Vec2(0, 0));
    expect(controller.measureStart, const Vec2(0, 0));
    expect(controller.measureEnd, isNull);

    controller.placeMeasurePoint(const Vec2(30, 40));
    expect(controller.measureStart, const Vec2(0, 0));
    expect(controller.measureEnd, const Vec2(30, 40));

    controller.placeMeasurePoint(const Vec2(100, 100));
    expect(controller.measureStart, const Vec2(100, 100));
    expect(controller.measureEnd, isNull);
  });

  test('snapPoint snaps a nearby click to an exact hole center', () {
    final controller = DesignController(TemplateLibrary());
    controller.project = controller.project.copyWith(holes: [
      Hole(id: 'h1', type: HoleType.screw, position: const Vec2(50, 50)),
    ]);

    final snapped = snapPoint(const Vec2(51, 49), controller);
    expect(snapped, const Vec2(50, 50));
  });

  test('snapPoint snaps a nearby click to the nearest point on a box edge', () {
    final controller = DesignController(TemplateLibrary());
    // Default box outline is a 150x90mm rectangle with a corner at (0,0).
    final snapped = snapPoint(const Vec2(75, 1.5), controller);
    expect(snapped.x, closeTo(75, 1e-9));
    expect(snapped.y, closeTo(0, 1e-9));
  });

  test('snapPoint leaves a click unchanged when nothing is within tolerance', () {
    final controller = DesignController(TemplateLibrary());
    const raw = Vec2(75, 45); // center of the default 150x90mm box
    expect(snapPoint(raw, controller), raw);
  });

  test('snapPoint snaps to the center of a slot\'s rounded end, not just its overall center', () {
    final controller = DesignController(TemplateLibrary());
    // A 20x6mm slot centered at (50, 50): each rounded end's own center sits
    // (length/2 - width/2) = 7mm out from the slot's overall center.
    controller.project = controller.project.copyWith(holes: [
      Hole(id: 'h1', type: HoleType.slot, position: const Vec2(50, 50), slotLength: 20, slotWidth: 6),
    ]);

    final snapped = snapPoint(const Vec2(58, 51), controller);
    expect(snapped.x, closeTo(57, 1e-6));
    expect(snapped.y, closeTo(50, 1e-6));
  });

  test('snapPoint snaps to a mounting hole baked directly into a placed template', () {
    final library = TemplateLibrary();
    final template = library.importJson(jsonEncode({
      'id': 'board_with_hole',
      'name': 'Test Board',
      'category': 'controller',
      'entities': [
        {
          'type': 'polyline',
          'closed': true,
          'vertices': [
            {'x': 0, 'y': 0, 'bulge': 0},
            {'x': 20, 'y': 0, 'bulge': 0},
            {'x': 20, 'y': 10, 'bulge': 0},
            {'x': 0, 'y': 10, 'bulge': 0},
          ],
        },
        {
          'type': 'circle',
          'center': {'x': 5, 'y': 5},
          'radius': 1.5,
        },
      ],
    }));
    final controller = DesignController(library);
    controller.project = controller.project.copyWith(placedTemplates: [
      PlacedTemplate(id: 'p1', templateId: template.id, position: const Vec2(100, 100)),
    ]);

    // The hole sits at local (5, 5) -> absolute (105, 105); only reachable
    // via the baked-in circle's own center, not the placed template's
    // origin. Clicking well inside the 1.5mm-radius circle (rather than
    // near its rim) so the center -- not a nearer point on the traced
    // outline -- is unambiguously the closest candidate.
    final snapped = snapPoint(const Vec2(105.2, 105.2), controller);
    expect(snapped.x, closeTo(105, 1e-6));
    expect(snapped.y, closeTo(105, 1e-6));
  });
}
