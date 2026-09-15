// Exercises buildPlateMesh end-to-end against a real bundled box template
// (which — unlike the synthetic squares in mesh_test.dart — bakes its own
// mounting-flange holes in alongside the outline, the same shape as
// mesh_test.dart's low-level extrudePlate tests but through the actual
// BoxProject/Hole/TemplateLibrary pipeline used by the app).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/design/design_controller.dart';
import 'package:box_design_flutter/geometry/mesh.dart';
import 'package:box_design_flutter/geometry/triangulate.dart';
import 'package:box_design_flutter/models/hole.dart';
import 'package:box_design_flutter/models/placed_template.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/services/mesh_export.dart';
import 'package:box_design_flutter/services/template_library.dart';

double _topFaceArea(Mesh mesh) {
  final topZ = mesh.vertices.map((v) => v.z).reduce(math.max);
  final isTop = <bool>[for (final v in mesh.vertices) v.z == topZ];
  var area = 0.0;
  for (final t in mesh.triangles) {
    if (isTop[t[0]] && isTop[t[1]] && isTop[t[2]]) {
      final a = mesh.vertices[t[0]], b = mesh.vertices[t[1]], c = mesh.vertices[t[2]];
      area += triangleArea(Vec2(a.x, a.y), Vec2(b.x, b.y), Vec2(c.x, c.y));
    }
  }
  return area;
}

void main() {
  test('a real box template\'s own baked-in mounting holes are cut through the plate', () {
    final assetJson = File('assets/templates/bud_nbf32016.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final circleCount = (decoded['entities'] as List).where((e) => e['type'] == 'circle').length;
    final circleRadius = ((decoded['entities'] as List).firstWhere((e) => e['type'] == 'circle')['radius'] as num).toDouble();
    expect(circleCount, greaterThan(0), reason: 'fixture assumption: this template bakes in mounting holes');

    final library = TemplateLibrary();
    library.importJson(assetJson); // re-uses the real id/category from the file
    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);

    controller.project = controller.project.copyWith(holes: [
      Hole(id: 'h1', type: HoleType.screw, position: const Vec2(150, 20), diameter: 5),
      Hole(id: 'h2', type: HoleType.zipTie, position: const Vec2(150, 180), slotLength: 15, slotWidth: 4),
    ]);

    final boxWidth = controller.project.boxWidth;
    final boxHeight = controller.project.boxHeight;

    final mesh = buildPlateMesh(controller.project, library, thicknessMm: 5);

    // Reconstruct the top face's net area straight from the mesh (half the
    // mesh's vertices are the top face, at z == thickness) to prove the
    // holes actually reduced the material rather than just trusting
    // buildPlateMesh's internal wiring.
    final topArea = _topFaceArea(mesh);

    final screwHoleArea = math.pi * 2.5 * 2.5; // 5mm diameter
    // Redesigned zip-tie: two round holes of diameter == slotWidth.
    final zipTieArea = 2 * math.pi * 2.0 * 2.0; // 4mm diameter each
    final bakedHolesArea = circleCount * math.pi * circleRadius * circleRadius;
    final expectedArea = boxWidth * boxHeight - bakedHolesArea - screwHoleArea - zipTieArea;

    expect(topArea, closeTo(expectedArea, expectedArea * 0.01));
  });

  test('a placed template\'s own mounting holes are also cut through the plate', () {
    final assetJson = File('assets/templates/bud_nbf32016.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;

    final library = TemplateLibrary();
    library.importJson(assetJson);
    // A small board with two of its own mounting holes, placed well inside
    // the box — its holes must show up in the plate too, since it's
    // physically screwed to it.
    final board = library.importJson(jsonEncode({
      'id': 'test_board',
      'name': 'Test Board',
      'category': 'controller',
      'entities': [
        {
          'type': 'polyline',
          'closed': true,
          'vertices': [
            {'x': 0, 'y': 0, 'bulge': 0},
            {'x': 40, 'y': 0, 'bulge': 0},
            {'x': 40, 'y': 20, 'bulge': 0},
            {'x': 0, 'y': 20, 'bulge': 0},
          ],
        },
        {
          'type': 'circle',
          'center': {'x': 5, 'y': 5},
          'radius': 1.5,
        },
        {
          'type': 'circle',
          'center': {'x': 35, 'y': 15},
          'radius': 1.5,
        },
      ],
    }));

    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);
    controller.project = controller.project.copyWith(placedTemplates: [
      PlacedTemplate(id: 'p1', templateId: board.id, position: const Vec2(100, 100)),
    ]);

    final boxArea = controller.project.boxWidth * controller.project.boxHeight;
    final withoutBoardHoles = buildPlateMesh(controller.project, library, thicknessMm: 5);
    final areaIgnoringNothing = _topFaceArea(withoutBoardHoles);

    final boardHolesArea = 2 * math.pi * 1.5 * 1.5;
    // The BUD template's own baked-in mounting holes are always cut too.
    final bakedCircles = (decoded['entities'] as List).where((e) => e['type'] == 'circle').toList();
    final bakedHolesArea = bakedCircles.fold(0.0, (s, c) => s + math.pi * ((c['radius'] as num) * (c['radius'] as num)));
    final expectedArea = boxArea - bakedHolesArea - boardHolesArea;

    expect(areaIgnoringNothing, closeTo(expectedArea, expectedArea * 0.01));
  });
}
