import '../models/vec2.dart';

double _cross(Vec2 o, Vec2 a, Vec2 b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

double signedArea(List<Vec2> poly) {
  var sum = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}

double triangleArea(Vec2 a, Vec2 b, Vec2 c) => _cross(a, b, c).abs() / 2;

// ---------------------------------------------------------------------------
// Robust geometric predicates. Coordinates are mm on a ~0.001 grid, so a
// tolerance of 1e-9 on cross products (mm²) cleanly separates "collinear"
// from "not" without ever mattering for real geometry.
// ---------------------------------------------------------------------------

const _eps = 1e-9;

int _sign(double v) => v > _eps ? 1 : (v < -_eps ? -1 : 0);

bool _samePos(Vec2 a, Vec2 b) => (a.x - b.x).abs() < _eps && (a.y - b.y).abs() < _eps;

bool _onSegment(Vec2 a, Vec2 b, Vec2 p) {
  if (_sign(_cross(a, b, p)) != 0) return false;
  return p.x >= (a.x < b.x ? a.x : b.x) - _eps &&
      p.x <= (a.x > b.x ? a.x : b.x) + _eps &&
      p.y >= (a.y < b.y ? a.y : b.y) - _eps &&
      p.y <= (a.y > b.y ? a.y : b.y) + _eps;
}

/// True if the open direction a -> [b] lies strictly inside the polygon's
/// interior wedge at vertex [a] (whose neighbours along a CCW boundary are
/// [a0] before and [a1] after). O'Rourke's InCone.
bool _inCone(Vec2 a0, Vec2 a, Vec2 a1, Vec2 b) {
  if (_sign(_cross(a, a1, a0)) >= 0) {
    // Convex or flat vertex.
    return _sign(_cross(a, b, a0)) > 0 && _sign(_cross(b, a, a1)) > 0;
  }
  // Reflex vertex: b is inside unless it's in the exterior wedge.
  return !(_sign(_cross(a, b, a1)) >= 0 && _sign(_cross(b, a, a0)) >= 0);
}

/// True if the segment p-q touches or crosses the boundary edge e1-e2 anywhere
/// other than by simply *meeting it at an endpoint*: a shared endpoint (by
/// position -- bridging makes several vertices share a position) is fine
/// unless the two segments then overlap along the same line.
bool _segmentConflictsWithEdge(Vec2 p, Vec2 q, Vec2 e1, Vec2 e2) {
  if (_samePos(e1, e2)) return false;
  final e1p = _samePos(e1, p), e1q = _samePos(e1, q), e2p = _samePos(e2, p), e2q = _samePos(e2, q);
  if ((e1p && e2q) || (e1q && e2p)) return true; // the edge *is* the segment
  if (e1p || e1q || e2p || e2q) {
    final Vec2 s, f, o;
    if (e1p || e2p) {
      s = p;
      f = q;
      o = e1p ? e2 : e1;
    } else {
      s = q;
      f = p;
      o = e1q ? e2 : e1;
    }
    if (_sign(_cross(s, f, o)) != 0) return false;
    return (f.x - s.x) * (o.x - s.x) + (f.y - s.y) * (o.y - s.y) > 0;
  }
  final d1 = _sign(_cross(e1, e2, p));
  final d2 = _sign(_cross(e1, e2, q));
  final d3 = _sign(_cross(p, q, e1));
  final d4 = _sign(_cross(p, q, e2));
  if (d1 * d2 < 0 && d3 * d4 < 0) return true;
  return _onSegment(e1, e2, p) || _onSegment(e1, e2, q) || _onSegment(p, q, e1) || _onSegment(p, q, e2);
}

bool _inClosedTriangle(Vec2 p, Vec2 a, Vec2 b, Vec2 c) {
  final d1 = _sign(_cross(a, b, p));
  final d2 = _sign(_cross(b, c, p));
  final d3 = _sign(_cross(c, a, p));
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

// ---------------------------------------------------------------------------
// Hole bridging
// ---------------------------------------------------------------------------

/// Result of [mergeHolesIntoOuter]: the single bridged [polygon] ready for
/// ear-clipping, plus the outer boundary and each hole's own boundary loop
/// exactly as they should be walked for wall generation.
class MergeResult {
  final List<Vec2> polygon;
  final List<Vec2> outerBoundary;
  final List<List<Vec2>> holeBoundaries;
  const MergeResult(this.polygon, this.outerBoundary, this.holeBoundaries);
}

/// Merges each hole in [holesCcw] into [outerCcw] by joining it to a boundary
/// vertex it can actually *see* (the classic zero-width "keyhole" bridge),
/// producing a single weakly-simple polygon suitable for ear-clipping. Both
/// the outer boundary and every hole must already be closed loops (first
/// point not repeated at the end).
///
/// A bridge is only accepted if it leaves both endpoints into the plate's
/// interior and touches no other boundary edge (including every hole not yet
/// merged). Because it only ever joins existing vertices, no new points are
/// invented -- every vertex stays exactly on the original geometry, so
/// same-height holes, collinear edges etc. need no special-casing.
MergeResult mergeHolesIntoOuter(List<Vec2> outerCcw, List<List<Vec2>> holesCcw) {
  var working = List<Vec2>.from(outerCcw);
  if (signedArea(working) < 0) working = working.reversed.toList();
  final outerBoundary = List<Vec2>.from(working);

  // Each hole as a CW loop (interior of the plate on its left, like the CCW
  // outer boundary), so the same InCone test works for both.
  final holes = <List<Vec2>>[
    for (final h in holesCcw) (signedArea(h) > 0 ? h.reversed.toList() : List<Vec2>.from(h)),
  ];
  final holeBoundaries = [for (final h in holesCcw) List<Vec2>.from(h)];

  double maxX(List<Vec2> h) => h.map((p) => p.x).reduce((x, y) => x > y ? x : y);
  final order = List<int>.generate(holes.length, (i) => i)..sort((a, b) => maxX(holes[b]).compareTo(maxX(holes[a])));
  final merged = <int>{};

  bool bridgeOk(Vec2 m, int mi, List<Vec2> hole, Vec2 v, int vi) {
    final hn = hole.length;
    if (!_inCone(hole[(mi - 1 + hn) % hn], m, hole[(mi + 1) % hn], v)) return false;
    final wn = working.length;
    if (!_inCone(working[(vi - 1 + wn) % wn], v, working[(vi + 1) % wn], m)) return false;
    for (var i = 0; i < wn; i++) {
      if (_segmentConflictsWithEdge(m, v, working[i], working[(i + 1) % wn])) return false;
    }
    for (var h = 0; h < holes.length; h++) {
      if (merged.contains(h)) continue; // already part of `working`
      final loop = holes[h];
      for (var i = 0; i < loop.length; i++) {
        if (_segmentConflictsWithEdge(m, v, loop[i], loop[(i + 1) % loop.length])) return false;
      }
    }
    return true;
  }

  double dist2(Vec2 a, Vec2 b) => (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);

  for (final holeIndex in order) {
    final hole = holes[holeIndex];
    if (hole.length < 3) {
      merged.add(holeIndex);
      continue;
    }

    // Try the hole's vertices from rightmost to leftmost; for each, the
    // nearest working vertex it can see.
    final mOrder = List<int>.generate(hole.length, (i) => i)..sort((a, b) => hole[b].x.compareTo(hole[a].x));
    int? bestM;
    int? bestV;
    for (final mi in mOrder) {
      final m = hole[mi];
      final byDist = List<int>.generate(working.length, (i) => i)
        ..sort((a, b) => dist2(working[a], m).compareTo(dist2(working[b], m)));
      for (final vi in byDist) {
        if (bridgeOk(m, mi, hole, working[vi], vi)) {
          bestM = mi;
          bestV = vi;
          break;
        }
      }
      if (bestM != null) break;
    }
    // Nothing visible (shouldn't happen for a valid, non-overlapping hole):
    // fall back to the nearest vertex so a plate is still produced.
    if (bestM == null) {
      bestM = mOrder.first;
      final m = hole[bestM];
      var bd = double.infinity;
      for (var i = 0; i < working.length; i++) {
        final d = dist2(working[i], m);
        if (d < bd) {
          bd = d;
          bestV = i;
        }
      }
    }

    final mi = bestM;
    final vi = bestV!;
    final rotatedHole = [for (var k = 0; k < hole.length; k++) hole[(mi + k) % hole.length]];
    working = [
      ...working.sublist(0, vi + 1),
      ...rotatedHole,
      hole[mi], // back to the bridge's hole end
      working[vi], // ...and back along the bridge
      ...working.sublist(vi + 1),
    ];
    merged.add(holeIndex);
  }

  return MergeResult(working, outerBoundary, holeBoundaries);
}

// ---------------------------------------------------------------------------
// Ear clipping
// ---------------------------------------------------------------------------

/// Ear-clipping triangulation of a simple (possibly already hole-bridged,
/// i.e. weakly simple) polygon. Returns triangles as index triples into
/// [pts]. An ear is only clipped when its closing diagonal is a *proper*
/// diagonal -- leaves both ends into the interior, touches no other boundary
/// edge -- and the triangle holds no other vertex, so every triangle emitted
/// is non-degenerate and the result tiles the polygon exactly.
List<List<int>> earClipTriangulate(List<Vec2> pts) {
  final n = pts.length;
  if (n < 3) return [];

  var remaining = List<int>.generate(n, (i) => i);
  if (signedArea(pts) < 0) remaining = remaining.reversed.toList();

  final triangles = <List<int>>[];

  bool isEar(int i, {required bool strict}) {
    final m = remaining.length;
    final ip = remaining[(i - 1 + m) % m];
    final ic = remaining[i];
    final inx = remaining[(i + 1) % m];
    final a = pts[ip], b = pts[ic], c = pts[inx];
    if (_sign(_cross(a, b, c)) <= 0) return false;

    for (final j in remaining) {
      if (j == ip || j == ic || j == inx) continue;
      final p = pts[j];
      if (_samePos(p, a) || _samePos(p, b) || _samePos(p, c)) continue;
      if (_inClosedTriangle(p, a, b, c)) return false;
    }
    if (!strict) return true;

    final ipp = remaining[(i - 2 + m) % m];
    final inn = remaining[(i + 2) % m];
    if (!_inCone(pts[ipp], a, b, c)) return false;
    if (!_inCone(b, c, pts[inn], a)) return false;
    for (var k = 0; k < m; k++) {
      if (_segmentConflictsWithEdge(a, c, pts[remaining[k]], pts[remaining[(k + 1) % m]])) return false;
    }
    return true;
  }

  var start = 0;
  var guard = 0;
  while (remaining.length > 3 && guard++ < n * 4) {
    final m = remaining.length;
    var found = -1;
    for (var t = 0; t < m && found == -1; t++) {
      final i = (start + t) % m;
      if (isEar(i, strict: true)) found = i;
    }
    if (found == -1) {
      // Numerically awkward input: settle for the smallest convex ear whose
      // triangle is empty, then the smallest convex one, then anything.
      var bestArea = double.infinity;
      for (final needEmpty in [true, false]) {
        for (var i = 0; i < m; i++) {
          final a = pts[remaining[(i - 1 + m) % m]], b = pts[remaining[i]], c = pts[remaining[(i + 1) % m]];
          if (_sign(_cross(a, b, c)) <= 0) continue;
          if (needEmpty && !isEar(i, strict: false)) continue;
          final area = triangleArea(a, b, c);
          if (area < bestArea) {
            bestArea = area;
            found = i;
          }
        }
        if (found != -1) break;
      }
      if (found == -1) {
        var bestCross = double.negativeInfinity;
        for (var i = 0; i < m; i++) {
          final cr = _cross(pts[remaining[(i - 1 + m) % m]], pts[remaining[i]], pts[remaining[(i + 1) % m]]);
          if (cr > bestCross) {
            bestCross = cr;
            found = i;
          }
        }
      }
    }

    final ip = remaining[(found - 1 + m) % m];
    final ic = remaining[found];
    final inx = remaining[(found + 1) % m];
    triangles.add([ip, ic, inx]);
    remaining = [for (var i = 0; i < m; i++) if (i != found) remaining[i]];
    start = (found - 1 + remaining.length) % remaining.length;
  }
  if (remaining.length == 3) {
    triangles.add([remaining[0], remaining[1], remaining[2]]);
  }

  return triangles.where((t) => triangleArea(pts[t[0]], pts[t[1]], pts[t[2]]) > 1e-9).toList();
}
