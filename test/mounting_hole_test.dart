import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/design/design_controller.dart';
import 'package:box_design_flutter/geometry/placed_entities.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
import 'package:box_design_flutter/models/placed_template.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/services/template_library.dart';

String _templateJson() => jsonEncode({
      'id': 'board_with_holes',
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
          'radius': 2.0,
        },
        {
          'type': 'circle',
          'center': {'x': 15, 'y': 5},
          'radius': 2.0,
        },
      ],
    });

void main() {
  test('placedTemplateEntities leaves circles unchanged with no override', () {
    final library = TemplateLibrary();
    final template = library.importJson(_templateJson());
    final placed = PlacedTemplate(id: 'p1', templateId: template.id, position: const Vec2(0, 0));

    final entities = placedTemplateEntities(template, placed);
    final circles = entities.whereType<DxfCircle>().toList();

    expect(circles, hasLength(2));
    for (final c in circles) {
      expect(c.radius, closeTo(2.0, 1e-9));
    }
  });

  test('placedTemplateEntities resizes every circle when an override is set, leaving the outline alone', () {
    final library = TemplateLibrary();
    final template = library.importJson(_templateJson());
    final placed = PlacedTemplate(id: 'p1', templateId: template.id, position: const Vec2(0, 0))
        .withHoleDiameterOverride(6.0);

    final entities = placedTemplateEntities(template, placed);
    final circles = entities.whereType<DxfCircle>().toList();
    final polylines = entities.whereType<DxfPolyline>().toList();

    expect(circles, hasLength(2));
    for (final c in circles) {
      expect(c.radius, closeTo(3.0, 1e-9)); // 6mm diameter -> 3mm radius
    }
    expect(polylines, hasLength(1));
    expect(polylines.single.vertices.map((v) => v.point.x), containsAll([0.0, 20.0]));
  });

  test('DesignController.setMountingHoleDiameter sets and clears the override', () {
    final library = TemplateLibrary();
    final template = library.importJson(_templateJson());
    final controller = DesignController(library);
    final placed = PlacedTemplate(id: 'p1', templateId: template.id, position: const Vec2(0, 0));
    controller.project = controller.project.copyWith(placedTemplates: [placed]);

    controller.setMountingHoleDiameter('p1', 6.0);
    expect(controller.project.placedTemplates.single.holeDiameterOverride, 6.0);

    controller.setMountingHoleDiameter('p1', null);
    expect(controller.project.placedTemplates.single.holeDiameterOverride, isNull);
  });
}
