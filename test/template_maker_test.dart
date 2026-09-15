import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/models/controller_template.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
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

  test('a positive cornerRadius produces an 8-vertex filleted outline with the right bounding box', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerRadius(6);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    expect(outline.vertices, hasLength(8));
    expect(outline.vertices.where((v) => v.bulge != 0), hasLength(4));
    // The bounding box still matches the outer envelope, since toPoints()
    // flattens the corner arcs out to the full radius.
    expect(outline.boundingBox.width, closeTo(80, 0.05));
    expect(outline.boundingBox.height, closeTo(50, 0.05));
  });

  test('cornerRadius is clamped so it can never exceed half the smaller side', () {
    final controller = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerRadius(1000);

    final outline = controller.toTemplate().entities.first as DxfPolyline;
    // Half of the smaller side (50) is 25 -- the first vertex sits at (r, 0).
    expect(outline.vertices.first.point.x, closeTo(25, 1e-9));
  });

  test('loadFromTemplate round-trips a filleted outline back to its corner radius', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50)
      ..setCornerRadius(6);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.outlineWidth, closeTo(80, 1e-9));
    expect(loaded.outlineHeight, closeTo(50, 1e-9));
    expect(loaded.cornerRadius, closeTo(6, 1e-9));
  });

  test('loadFromTemplate reads back cornerRadius 0 for a plain rectangle', () {
    final original = TemplateMakerController()
      ..setOutlineWidth(80)
      ..setOutlineHeight(50);
    final template = original.toTemplate();

    final loaded = TemplateMakerController()..loadFromTemplate(template);
    expect(loaded.cornerRadius, 0);
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
}
