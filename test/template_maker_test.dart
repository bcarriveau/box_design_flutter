import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/models/controller_template.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/template_maker/template_maker_controller.dart';

void main() {
  test('cornerRadius 0 produces a plain 4-vertex rectangle outline', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices, hasLength(4));
    expect(outline.vertices.every((v) => v.bulge == 0), isTrue);
    expect(outline.boundingBox.width, closeTo(80, 1e-9));
    expect(outline.boundingBox.height, closeTo(50, 1e-9));
  });

  test('a positive cornerSize with fillet style produces an 8-vertex filleted outline with the right bounding box', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.fillet)
      ..setCornerSize(6);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices, hasLength(8));
    expect(outline.vertices.where((v) => v.bulge != 0), hasLength(4));
    // The bounding box still matches the outer envelope, since toPoints()
    // flattens the corner arcs out to the full radius.
    expect(outline.boundingBox.width, closeTo(80, 0.05));
    expect(outline.boundingBox.height, closeTo(50, 0.05));
  });

  test('a positive cornerSize with chamfer style produces an 8-vertex chamfered outline with no bulge', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.chamfer)
      ..setCornerSize(6);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices, hasLength(8));
    expect(outline.vertices.every((v) => v.bulge == 0), isTrue);
    expect(outline.boundingBox.width, closeTo(80, 1e-9));
    expect(outline.boundingBox.height, closeTo(50, 1e-9));
  });

  test('cornerSize is clamped so it can never exceed half the smaller side', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.fillet)
      ..setCornerSize(1000);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    // Half of the smaller side (50) is 25 -- the first vertex sits at (r, 0).
    expect(outline.vertices.first.point.x, closeTo(25, 1e-9));
  });

  test('loadFromTemplate round-trips a filleted outline back to its corner style and size', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.fillet)
      ..setCornerSize(6);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.outlineWidth, closeTo(80, 1e-9));
    expect(loaded.outlineHeight, closeTo(50, 1e-9));
    expect(loaded.cornerStyle, TemplateMakerCornerStyle.fillet);
    expect(loaded.cornerSize, closeTo(6, 1e-9));
  });

  test('loadFromTemplate round-trips a chamfered outline back to its corner style and size', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.chamfer)
      ..setCornerSize(6);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.outlineWidth, closeTo(80, 1e-9));
    expect(loaded.outlineHeight, closeTo(50, 1e-9));
    expect(loaded.cornerStyle, TemplateMakerCornerStyle.chamfer);
    expect(loaded.cornerSize, closeTo(6, 1e-9));
  });

  test('loadFromTemplate reads back cornerSize 0 for a plain rectangle', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.cornerSize, 0);
  });

  test('addQuickHolePattern places 4 round holes centered on the outline', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(100)
      ..setOutlineHeight(60)
      ..addQuickHolePattern(horizontalSpacing: 80, verticalSpacing: 40, diameter: 3.2);

    expect(controller.holes, hasLength(4));
    final positions = controller.holes.map((h) => (h.x, h.y)).toSet();
    expect(
      positions,
      {
        (10.0, 10.0),
        (10.0, 50.0),
        (90.0, 10.0),
        (90.0, 50.0),
      },
    );
    expect(controller.holes.every((h) => h.diameter == 3.2), isTrue);
    expect(controller.holes.every((h) => h.shape == TemplateMakerHoleShape.round), isTrue);
  });

  test('toTemplate carries category and holes through unchanged', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCategory(TemplateCategory.receiver)
      ..addHole();

    final template = controller.toTemplate();
    expect(template.category, TemplateCategory.receiver);
    expect(template.entities.whereType<DxfCircle>(), hasLength(1));
  });

  test('a positive cornerSize with cornerCut style produces a 12-vertex notched outline with the right bounding box', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.cornerCut)
      ..setCornerSize(8);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices, hasLength(12));
    expect(outline.vertices.every((v) => v.bulge == 0), isTrue);
    expect(outline.boundingBox.width, closeTo(80, 1e-9));
    expect(outline.boundingBox.height, closeTo(50, 1e-9));
  });

  test('cornerSize is clamped so it can never exceed half the smaller side (cornerCut style)', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.cornerCut)
      ..setCornerSize(1000);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices.first.point.x, closeTo(25, 1e-9));
  });

  test('changing cornerStyle swaps the outline shape produced for the same cornerSize', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.fillet)
      ..setCornerSize(6);
    expect(controller.cornerStyle, TemplateMakerCornerStyle.fillet);
    expect((controller.toTemplate().entities.first as DxfPolyline).vertices.any((v) => v.bulge != 0), isTrue);

    controller.setCornerStyle(TemplateMakerCornerStyle.cornerCut);
    expect(controller.cornerSize, 6);
    expect((controller.toTemplate().entities.first as DxfPolyline).vertices, hasLength(12));
  });

  test('loadFromTemplate round-trips a notched outline back to its cut size', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerStyle(TemplateMakerCornerStyle.cornerCut)
      ..setCornerSize(8);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.outlineWidth, closeTo(80, 1e-9));
    expect(loaded.outlineHeight, closeTo(50, 1e-9));
    expect(loaded.cornerStyle, TemplateMakerCornerStyle.cornerCut);
    expect(loaded.cornerSize, closeTo(8, 1e-9));
  });

  test('addSlot produces a closed stadium polyline with the right bounding box', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..addSlot();
    final hole = controller.holes.single;
    controller.updateHole(hole.id, x: 40, y: 25, slotLength: 20, slotWidth: 6);

    final template = controller.toTemplate();
    final slotEntity = template.entities.whereType<DxfPolyline>().last;
    expect(slotEntity.closed, isTrue);
    expect(slotEntity.boundingBox.width, closeTo(20, 0.05));
    expect(slotEntity.boundingBox.height, closeTo(6, 0.05));
    expect(slotEntity.boundingBox.center.x, closeTo(40, 0.05));
    expect(slotEntity.boundingBox.center.y, closeTo(25, 0.05));
  });

  test('a rotated slot swaps its bounding box dimensions', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..addSlot();
    final hole = controller.holes.single;
    controller.updateHole(hole.id, x: 40, y: 25, slotLength: 20, slotWidth: 6, rotationDeg: 90);

    final slotEntity = controller.toTemplate().entities.whereType<DxfPolyline>().last;
    expect(slotEntity.boundingBox.width, closeTo(6, 0.05));
    expect(slotEntity.boundingBox.height, closeTo(20, 0.05));
  });

  test('loadFromTemplate reads the outline size from separate line segments, not a single circle', () {
    // Mirrors what the KiCad plugin exports for an Edge.Cuts rectangle drawn
    // as four independent line segments (each with a degenerate, zero-area
    // bounding box) plus round mounting holes -- the outline used to be
    // picked as whichever single entity had the largest bounding-box area,
    // which was one of the holes here since every line's own area is 0.
    final template = ControllerTemplate(
      id: 'pb_16',
      name: 'PB_16',
      source: TemplateSource.imported,
      category: TemplateCategory.controller,
      entities: [
        DxfLine(const Vec2(148.6, 0), const Vec2(148.6, 76.4)),
        DxfLine(const Vec2(0, 76.4), const Vec2(0, 0)),
        DxfLine(const Vec2(148.6, 76.4), const Vec2(0, 76.4)),
        DxfLine(const Vec2(148.6, 0), const Vec2(0, 0)),
        DxfCircle(const Vec2(10.912, 71.5512), 1.85),
        DxfCircle(const Vec2(137.912, 71.5512), 1.85),
        DxfCircle(const Vec2(137.9266, 20.7512), 1.85),
        DxfCircle(const Vec2(10.9266, 20.7512), 1.85),
      ],
    );

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.outlineWidth, closeTo(148.6, 1e-6));
    expect(loaded.outlineHeight, closeTo(76.4, 1e-6));
    expect(loaded.cornerSize, 0);
    expect(loaded.holes, hasLength(4));
    for (final hole in loaded.holes) {
      expect(hole.diameter, closeTo(3.7, 1e-6));
    }
  });

  test('loadFromTemplate round-trips a slot hole back to its length/width/rotation', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..addSlot();
    final hole = original.holes.single;
    original.updateHole(hole.id, x: 30, y: 15, slotLength: 18, slotWidth: 5, rotationDeg: 35);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.holes, hasLength(1));
    final loadedHole = loaded.holes.single;
    expect(loadedHole.shape, TemplateMakerHoleShape.slot);
    expect(loadedHole.x, closeTo(30, 1e-6));
    expect(loadedHole.y, closeTo(15, 1e-6));
    expect(loadedHole.slotLength, closeTo(18, 1e-6));
    expect(loadedHole.slotWidth, closeTo(5, 1e-6));
    expect(loadedHole.rotationDeg, closeTo(35, 1e-6));
  });
}
