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
import 'package:box_design_flutter/models/dxf_entity.dart';
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

  test('a single hole near the box\'s own baked holes does not duplicate a wall edge', () {
    // Regression test for a real user-reported "malformed STL": on a box
    // template that already bakes in mounting holes of its own (like
    // ticonn_mounting_plate.json's two holes on its vertical centerline),
    // adding just one more hole near that same centerline made bridging
    // pick the same rectangle corner as an existing bake-in hole's bridge,
    // producing two different but positionally-identical ear-clipping
    // diagonals — a duplicated face once vertices are welded by position.
    final assetJson = File('assets/templates/ticonn_mounting_plate.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);
    controller.project = controller.project.copyWith(holes: [
      Hole(id: 'h1', type: HoleType.screw, position: const Vec2(78.88055466547041, 66.97985664251524), diameter: 3.355810361700363),
    ]);

    final mesh = buildPlateMesh(controller.project, library, thicknessMm: 5);
    _expectStrictManifold(mesh);
  });

  test('several holes all nearest the same rectangle corner still produce a strict manifold', () {
    // Regression test for the same class of bug as above, triggered instead
    // by several *unrelated* holes all naturally bridging toward the same
    // corner (nothing clustered near the box's own holes this time).
    final assetJson = File('assets/templates/ticonn_mounting_plate.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);
    controller.project = controller.project.copyWith(holes: [
      Hole(id: 'h1', type: HoleType.screw, position: const Vec2(59.27729454112653, 159.7840958291389), diameter: 5.006056967726834),
      Hole(id: 'h2', type: HoleType.screw, position: const Vec2(99.9724344414215, 85.24201437645418), diameter: 5.7387945105676375),
      Hole(id: 'h3', type: HoleType.screw, position: const Vec2(104.19772690812405, 144.63663582811952), diameter: 4.818995065098594),
      Hole(id: 'h4', type: HoleType.screw, position: const Vec2(104.404174600793, 13.966773300693486), diameter: 5.628505516354667),
    ]);

    final mesh = buildPlateMesh(controller.project, library, thicknessMm: 5);
    _expectStrictManifold(mesh);
  });

  test('circle-hole side walls contain no degenerate (near-zero-area) triangles', () {
    // Regression test for a real user-reported "corrupt STL": DxfCircle's
    // point list closes on itself with an *approximate* repeat of its first
    // point (cos(2*pi) landing a hair off 1.0), so the exact `==` check that
    // used to dedupe it missed the near-duplicate. The stray point survived
    // into the hole boundary and produced a hairline-thin side-wall
    // triangle — invisible in mm terms, but its two vertices round to the
    // *same* 6-decimal text in the exported ASCII STL, so the facet reads
    // back with two identical vertices and gets rejected as corrupt.
    final assetJson = File('assets/templates/cg1500_placeholder.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);

    final mesh = buildPlateMesh(controller.project, library, thicknessMm: 5);
    _expectStrictManifold(mesh);

    for (final t in mesh.triangles) {
      final a = mesh.vertices[t[0]];
      final b = mesh.vertices[t[1]];
      final c = mesh.vertices[t[2]];
      final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
      final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
      final nx = uy * vz - uz * vy;
      final ny = uz * vx - ux * vz;
      final nz = ux * vy - uy * vx;
      final areaSquared = (nx * nx + ny * ny + nz * nz) / 4;
      expect(areaSquared, greaterThan(1e-12), reason: 'degenerate triangle ${t[0]},${t[1]},${t[2]}: $a, $b, $c');
    }
  });

  test('a slot hole removes its full stadium area, not just its two end caps', () {
    // Regression test: HoleType.slot used to build its cut boundary out of
    // 4 separate entities (2 lines + 2 arcs). mesh_export.dart's hole-loop
    // builder treats each entity as its own independent closed loop, so the
    // 2-point lines were dropped (too few points) and the 2 arcs were each
    // implicitly closed by their own chord -- cutting only the two
    // semicircular end caps and leaving the whole rectangular middle
    // section of the slot as solid, uncut material. Fixed by representing
    // the slot as one closed polyline (see stadiumVertices).
    const outerW = 100.0, outerH = 60.0;
    final library = TemplateLibrary();
    final controller = DesignController(library);
    controller.project = controller.project.copyWith(
      boxOutline: [
        DxfPolyline([
          const PolyVertex(Vec2(0, 0)),
          const PolyVertex(Vec2(outerW, 0)),
          const PolyVertex(Vec2(outerW, outerH)),
          const PolyVertex(Vec2(0, outerH)),
        ], closed: true),
      ],
      holes: [Hole(id: 'h1', type: HoleType.slot, position: const Vec2(50, 30), slotLength: 20, slotWidth: 6)],
    );

    final mesh = buildPlateMesh(controller.project, library, thicknessMm: 5);
    _expectStrictManifold(mesh);

    final topArea = _topFaceArea(mesh);
    const r = 6 / 2;
    const hl = 20 / 2 - r;
    final slotArea = (2 * hl) * (2 * r) + math.pi * r * r;
    final expectedArea = outerW * outerH - slotArea;
    expect(topArea, closeTo(expectedArea, expectedArea * 0.01));
  });

  test('addStandoffs raises a boss (matching the hole\'s own radius) on every controller/receiver mounting hole', () {
    final assetJson = File('assets/templates/bud_nbf32016.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final board = library.importJson(jsonEncode({
      'id': 'test_controller_board',
      'name': 'Test Controller Board',
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

    final plain = buildPlateMesh(controller.project, library, thicknessMm: 5);
    final withStandoffs = buildPlateMesh(
      controller.project,
      library,
      thicknessMm: 5,
      addStandoffs: true,
      standoffHeight: 3,
      standoffWallThickness: 2,
    );

    expect(withStandoffs.vertices.length, greaterThan(plain.vertices.length));
    expect(withStandoffs.triangles.length, greaterThan(plain.triangles.length));

    final plainMaxZ = plain.vertices.map((v) => v.z).reduce(math.max);
    final standoffMaxZ = withStandoffs.vertices.map((v) => v.z).reduce(math.max);
    expect(standoffMaxZ, closeTo(plainMaxZ + 3, 1e-9));

    // Standoffs are appended as their own independent solids (see
    // buildAnnularTube) -- the plate portion of the combined mesh should be
    // untouched, so its own directed edges still each appear exactly once.
    final plateEdgeCount = <String, int>{};
    for (final t in withStandoffs.triangles.take(plain.triangles.length)) {
      for (var i = 0; i < 3; i++) {
        final key = '${t[i]}->${t[(i + 1) % 3]}';
        plateEdgeCount[key] = (plateEdgeCount[key] ?? 0) + 1;
      }
    }
    for (final entry in plateEdgeCount.entries) {
      expect(entry.value, 1, reason: 'plate edge ${entry.key} appears ${entry.value} times');
    }
  });

  test('addStandoffs is a no-op with no controller/receiver boards placed', () {
    final assetJson = File('assets/templates/bud_nbf32016.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);

    final plain = buildPlateMesh(controller.project, library, thicknessMm: 5);
    final withStandoffs = buildPlateMesh(controller.project, library, thicknessMm: 5, addStandoffs: true);
    expect(withStandoffs.vertices.length, plain.vertices.length);
    expect(withStandoffs.triangles.length, plain.triangles.length);
  });

  test('addStandoffs skips power-supply boards', () {
    final assetJson = File('assets/templates/bud_nbf32016.json').readAsStringSync();
    final decoded = jsonDecode(assetJson) as Map<String, dynamic>;
    final library = TemplateLibrary();
    library.importJson(assetJson);
    final board = library.importJson(jsonEncode({
      'id': 'test_power_supply_board',
      'name': 'Test PSU',
      'category': 'powerSupply',
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
      ],
    }));

    final controller = DesignController(library);
    controller.applyBoxTemplate(decoded['id'] as String);
    controller.project = controller.project.copyWith(placedTemplates: [
      PlacedTemplate(id: 'p1', templateId: board.id, position: const Vec2(100, 100)),
    ]);

    final plain = buildPlateMesh(controller.project, library, thicknessMm: 5);
    final withStandoffs = buildPlateMesh(controller.project, library, thicknessMm: 5, addStandoffs: true);
    expect(withStandoffs.vertices.length, plain.vertices.length);
    expect(withStandoffs.triangles.length, plain.triangles.length);
  });
}

/// Every directed edge of a closed, watertight mesh must have a matching
/// edge in the opposite direction exactly once — see mesh_test.dart's
/// `_expectManifold` for the low-level version of this same check.
void _expectStrictManifold(Mesh mesh) {
  final edgeCount = <String, int>{};
  for (final t in mesh.triangles) {
    for (var i = 0; i < 3; i++) {
      final key = '${t[i]}->${t[(i + 1) % 3]}';
      edgeCount[key] = (edgeCount[key] ?? 0) + 1;
    }
  }
  for (final entry in edgeCount.entries) {
    expect(entry.value, 1, reason: 'directed edge ${entry.key} appears ${entry.value} times (should be exactly 1)');
  }
}
