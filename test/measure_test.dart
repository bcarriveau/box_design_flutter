import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/design/design_controller.dart';
import 'package:box_design_flutter/design/snap.dart';
import 'package:box_design_flutter/models/hole.dart';
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
}
