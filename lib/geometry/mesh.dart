import '../models/vec2.dart';
import 'triangulate.dart';

class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// A triangle mesh: [triangles] are index triples into [vertices], each
/// wound counter-clockwise when viewed from the direction its face should
/// be visible from (i.e. from outside a solid).
class Mesh {
  final List<Vec3> vertices;
  final List<List<int>> triangles;

  const Mesh(this.vertices, this.triangles);
}

/// Extrudes a flat [outer] boundary (with [holes] cut all the way through)
/// into a solid plate of [thickness] mm, for 3D printing. Coordinates are
/// mm; the result sits between z=0 and z=thickness.
Mesh extrudePlate({
  required List<Vec2> outer,
  required List<List<Vec2>> holes,
  required double thickness,
}) {
  var outerCcw = List<Vec2>.from(outer);
  if (signedArea(outerCcw) < 0) outerCcw = outerCcw.reversed.toList();

  final holesCcw = [
    for (final h in holes)
      if (h.length >= 3) (signedArea(h) < 0 ? h.reversed.toList() : List<Vec2>.from(h)),
  ];

  final mergeResult = mergeHolesIntoOuter(outerCcw, holesCcw);
  final merged = mergeResult.polygon;
  final faceTriangles = earClipTriangulate(merged);

  final vertices = <Vec3>[];
  // Every (x, y) that appears more than once (e.g. an outer vertex used both
  // by the top/bottom faces and by a wall, or duplicated across a bridge
  // seam) resolves to the same vertex index, so shared physical edges are
  // shared in the index buffer too — required for a manifold/watertight mesh.
  final topIndex = <Vec2, int>{};
  final bottomIndex = <Vec2, int>{};

  int topIdxFor(Vec2 p) => topIndex.putIfAbsent(p, () {
        vertices.add(Vec3(p.x, p.y, thickness));
        return vertices.length - 1;
      });
  int bottomIdxFor(Vec2 p) => bottomIndex.putIfAbsent(p, () {
        vertices.add(Vec3(p.x, p.y, 0));
        return vertices.length - 1;
      });

  final triangles = <List<int>>[];
  for (final t in faceTriangles) {
    final a = merged[t[0]];
    final b = merged[t[1]];
    final c = merged[t[2]];
    triangles.add([topIdxFor(a), topIdxFor(b), topIdxFor(c)]);
    triangles.add([bottomIdxFor(a), bottomIdxFor(c), bottomIdxFor(b)]);
  }

  void addWalls(List<Vec2> boundaryForOutwardNormal) {
    final n = boundaryForOutwardNormal.length;
    for (var i = 0; i < n; i++) {
      final a = boundaryForOutwardNormal[i];
      final b = boundaryForOutwardNormal[(i + 1) % n];
      if (a == b) continue;
      final aTop = topIdxFor(a);
      final bTop = topIdxFor(b);
      final aBot = bottomIdxFor(a);
      final bBot = bottomIdxFor(b);
      triangles.add([aBot, bBot, bTop]);
      triangles.add([aBot, bTop, aTop]);
    }
  }

  // Walked from mergeResult (not the raw outerCcw/holesCcw) so a wall
  // segment always matches a real top/bottom-face boundary edge — a Steiner
  // point [mergeHolesIntoOuter] inserts to split an edge for one bridge
  // must split the corresponding wall too, or the two surfaces disagree
  // about where the boundary actually runs and the mesh isn't watertight.
  addWalls(mergeResult.outerBoundary);
  for (final h in mergeResult.holeBoundaries) {
    addWalls(h.reversed.toList());
  }

  return Mesh(vertices, triangles);
}
