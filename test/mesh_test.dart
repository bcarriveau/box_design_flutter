import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/geometry/mesh.dart';
import 'package:box_design_flutter/geometry/triangulate.dart';
import 'package:box_design_flutter/models/vec2.dart';

List<Vec2> _rect(double w, double h) => [
      const Vec2(0, 0),
      Vec2(w, 0),
      Vec2(w, h),
      Vec2(0, h),
    ];

List<Vec2> _circle(Vec2 center, double radius, {int segments = 32}) => [
      for (var i = 0; i < segments; i++)
        Vec2(
          center.x + radius * math.cos(2 * math.pi * i / segments),
          center.y + radius * math.sin(2 * math.pi * i / segments),
        ),
    ];

double _sumTriangleAreas(List<Vec2> pts, List<List<int>> tris) =>
    tris.fold(0.0, (sum, t) => sum + triangleArea(pts[t[0]], pts[t[1]], pts[t[2]]));

/// Every edge of a closed, watertight mesh must be shared by exactly two
/// triangles (once in each direction).
void _expectManifold(Mesh mesh) {
  final directedEdges = <String>{};
  for (final t in mesh.triangles) {
    for (var i = 0; i < 3; i++) {
      final a = t[i];
      final b = t[(i + 1) % 3];
      directedEdges.add('$a->$b');
    }
  }
  for (final edge in directedEdges) {
    final parts = edge.split('->');
    final reverse = '${parts[1]}->${parts[0]}';
    expect(directedEdges.contains(reverse), isTrue, reason: 'edge $edge has no matching reverse edge $reverse');
  }
}

void main() {
  group('earClipTriangulate', () {
    test('a plain square triangulates to exactly its own area', () {
      final square = _rect(10, 10);
      final tris = earClipTriangulate(square);
      expect(_sumTriangleAreas(square, tris), closeTo(100, 1e-9));
    });

    test('a square with one circular hole loses exactly the hole area', () {
      final outer = _rect(10, 10);
      final hole = _circle(const Vec2(5, 5), 2, segments: 64);
      final merged = mergeHolesIntoOuter(outer, [hole]).polygon;
      final tris = earClipTriangulate(merged);
      final area = _sumTriangleAreas(merged, tris);
      expect(area, closeTo(100 - math.pi * 4, 0.05));
    });

    test('a square with two circular holes loses both hole areas', () {
      final outer = _rect(20, 10);
      final holeA = _circle(const Vec2(5, 5), 1.5, segments: 48);
      final holeB = _circle(const Vec2(15, 5), 1.5, segments: 48);
      final merged = mergeHolesIntoOuter(outer, [holeA, holeB]).polygon;
      final tris = earClipTriangulate(merged);
      final area = _sumTriangleAreas(merged, tris);
      expect(area, closeTo(200 - 2 * math.pi * 1.5 * 1.5, 0.05));
    });

    test('a rectangle with a 2x2 grid of holes loses exactly all four hole areas', () {
      // Regression test: multiple holes at different Y levels used to make
      // some holes' bridges cross another hole's bridge line undetected,
      // and separately made unrelated holes converge on the same bridge
      // vertex — both silently corrupted the triangulation without any
      // single hole being enough to reproduce it alone.
      final outer = _rect(30, 20);
      final holes = [
        _circle(const Vec2(5, 5), 1.5),
        _circle(const Vec2(25, 5), 1.5),
        _circle(const Vec2(5, 15), 1.5),
        _circle(const Vec2(25, 15), 1.5),
      ];
      final merged = mergeHolesIntoOuter(outer, holes).polygon;
      final tris = earClipTriangulate(merged);
      final area = _sumTriangleAreas(merged, tris);
      // Default 32-segment circles undershoot a true circle's area a little
      // (an inscribed 32-gon vs. the circle it approximates) — 0.5 comfortably
      // covers that discretization gap while still catching real corruption.
      expect(area, closeTo(600 - 4 * math.pi * 1.5 * 1.5, 0.5));
    });

    test('six holes (four corners + two near an edge) all cut correctly, matching a real reported bug', () {
      // Regression test for the exact shape of a real failure: a handful of
      // holes clustered such that several of them naturally want to bridge
      // to the same nearby corner.
      final outer = _rect(300, 200);
      final holes = [
        _circle(const Vec2(40, 45), 2),
        _circle(const Vec2(260, 45), 2),
        _circle(const Vec2(40, 170), 2),
        _circle(const Vec2(260, 170), 2),
        _circle(const Vec2(150, 20), 2.5),
        _circle(const Vec2(150, 180), 2.5),
      ];
      final merged = mergeHolesIntoOuter(outer, holes).polygon;
      final tris = earClipTriangulate(merged);
      final area = _sumTriangleAreas(merged, tris);
      final holesArea = 4 * math.pi * 4 + 2 * math.pi * 6.25;
      expect(area, closeTo(300 * 200 - holesArea, holesArea * 0.02));
    });
  });

  group('extrudePlate', () {
    test('produces a watertight (manifold) mesh for a plate with one hole', () {
      final mesh = extrudePlate(
        outer: _rect(10, 10),
        holes: [_circle(const Vec2(5, 5), 2, segments: 24)],
        thickness: 3,
      );
      _expectManifold(mesh);
    });

    test('produces a watertight mesh for a plate with two holes', () {
      final mesh = extrudePlate(
        outer: _rect(20, 10),
        holes: [
          _circle(const Vec2(5, 5), 1.5, segments: 24),
          _circle(const Vec2(15, 5), 1.5, segments: 24),
        ],
        thickness: 3,
      );
      _expectManifold(mesh);
    });

    test('produces a watertight mesh for a plate with no holes', () {
      final mesh = extrudePlate(outer: _rect(10, 10), holes: const [], thickness: 3);
      _expectManifold(mesh);
    });

    test('vertices span exactly [0, thickness] in z', () {
      final mesh = extrudePlate(
        outer: _rect(10, 10),
        holes: [_circle(const Vec2(5, 5), 2, segments: 24)],
        thickness: 4.5,
      );
      final zs = mesh.vertices.map((v) => v.z).toSet();
      expect(zs, {0.0, 4.5});
    });
  });
}
