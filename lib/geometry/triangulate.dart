import 'dart:math' as math;

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

/// Strictly interior — a point sitting exactly on an edge or at a corner
/// does *not* count. Bridging routinely creates several vertex pairs that
/// share a position (a hole's rightmost point and its bridge target each
/// appear twice, at topologically distinct places in the boundary); a
/// boundary-inclusive test flags those as "containing" any ear that
/// happens to touch that coordinate, which rejects almost every ear near a
/// bridge seam even though nothing actually overlaps.
bool _pointStrictlyInsideTriangle(Vec2 p, Vec2 a, Vec2 b, Vec2 c) {
  final d1 = _cross(a, b, p);
  final d2 = _cross(b, c, p);
  final d3 = _cross(c, a, p);
  return (d1 > 0 && d2 > 0 && d3 > 0) || (d1 < 0 && d2 < 0 && d3 < 0);
}

bool _properlyIntersect(Vec2 p1, Vec2 p2, Vec2 p3, Vec2 p4) {
  double d(Vec2 a, Vec2 b, Vec2 c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  final d1 = d(p3, p4, p1);
  final d2 = d(p3, p4, p2);
  final d3 = d(p1, p2, p3);
  final d4 = d(p1, p2, p4);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// Finds a vertex of [working] visible from [m] (a hole's rightmost point)
/// via the standard hole-bridging construction: cast a ray from [m] in the
/// +X direction, find the nearest edge it crosses, and take that edge's
/// rightmost endpoint as the candidate bridge target — then, if any other
/// vertex lies inside the (m, crossing point, candidate) triangle (i.e. it
/// actually occludes the view), swap to whichever occluder is closest in
/// angle to the ray. This is guaranteed to find a truly non-crossing bridge
/// for any simple polygon, which naive nearest-Euclidean-vertex search is
/// not (it was silently producing self-crossing merges on shapes with more
/// than one hole).
int _findBridgeTarget(Vec2 m, List<Vec2> working) {
  final n = working.length;

  // Every earlier bridge is a zero-width slit traversed once out and once
  // back along the exact same line, so a ray that crosses one crosses both
  // of its edges at the identical x — a pass-through, not a real block.
  // Collect every rightward crossing, then cancel same-x crossings out in
  // pairs (odd counts leave a genuine blocking edge behind) instead of
  // naively taking whichever crossing happens to be found first.
  final crossings = <(double x, int edgeA, int edgeB)>[];
  for (var i = 0; i < n; i++) {
    final a = working[i];
    final b = working[(i + 1) % n];
    if (a.y == b.y) continue;
    if ((a.y > m.y) == (b.y > m.y)) continue;
    final t = (m.y - a.y) / (b.y - a.y);
    final x = a.x + t * (b.x - a.x);
    if (x <= m.x) continue;
    crossings.add((x, i, (i + 1) % n));
  }
  crossings.sort((p, q) => p.$1.compareTo(q.$1));

  double? bestX;
  var edgeA = -1;
  var edgeB = -1;
  var i = 0;
  while (i < crossings.length) {
    var count = 1;
    while (i + count < crossings.length && (crossings[i + count].$1 - crossings[i].$1).abs() < 1e-6) {
      count++;
    }
    if (count.isOdd) {
      bestX = crossings[i].$1;
      edgeA = crossings[i].$2;
      edgeB = crossings[i].$3;
      break;
    }
    i += count;
  }

  if (bestX == null) {
    // m has nothing to its right (it's the rightmost point of everything) —
    // fall back to the closest vertex by angle from straight right.
    var best = 0;
    var bestAngle = double.infinity;
    for (var i = 0; i < n; i++) {
      if (working[i] == m) continue;
      final dx = working[i].x - m.x;
      final dy = working[i].y - m.y;
      final angle = math.atan2(dy.abs(), dx);
      if (angle < bestAngle) {
        bestAngle = angle;
        best = i;
      }
    }
    return best;
  }

  final iPoint = Vec2(bestX, m.y);
  // The standard construction just says "the crossed edge's endpoint with
  // the larger x", but a vertical edge (common — box outlines are usually
  // rectangle-ish) makes that a true tie; breaking it towards whichever
  // endpoint is closer to the ray gives a shorter, more natural bridge and
  // — importantly — stops every hole near that edge from bridging to the
  // exact same far corner, which was needlessly piling up bridges on one
  // vertex and defeating the ear tests around it.
  final xA = working[edgeA].x;
  final xB = working[edgeB].x;
  int pIdx;
  if ((xA - xB).abs() < 1e-9) {
    pIdx = (working[edgeA].y - m.y).abs() <= (working[edgeB].y - m.y).abs() ? edgeA : edgeB;
  } else {
    pIdx = xA > xB ? edgeA : edgeB;
  }
  double slope(Vec2 v) => (v.y - m.y).abs() / math.max(v.x - m.x, 1e-9);
  var bestSlope = slope(working[pIdx]);
  for (var i = 0; i < n; i++) {
    if (i == pIdx || i == edgeA || i == edgeB) continue;
    final v = working[i];
    if (v.x <= m.x) continue;
    if (_pointStrictlyInsideTriangle(v, m, iPoint, working[pIdx])) {
      final s = slope(v);
      if (s < bestSlope) {
        bestSlope = s;
        pIdx = i;
      }
    }
  }
  return pIdx;
}

Vec2 _rotate(Vec2 p, double cosT, double sinT) => Vec2(p.x * cosT - p.y * sinT, p.x * sinT + p.y * cosT);

/// Merges each hole in [holesCcw] into [outerCcw] by bridging it to a
/// visible boundary vertex, found via [_findBridgeTarget] (the classic
/// "keyhole" technique), producing a single simple polygon suitable for
/// ear-clipping. Both the outer boundary and every hole must already be
/// closed loops (first point not repeated at the end).
List<Vec2> mergeHolesIntoOuter(List<Vec2> outerCcw, List<List<Vec2>> holesCcw) {
  var working = List<Vec2>.from(outerCcw);
  if (signedArea(working) < 0) working = working.reversed.toList();

  final sortedHoles = [...holesCcw]
    ..sort((a, b) {
      final maxA = a.map((p) => p.x).reduce(math.max);
      final maxB = b.map((p) => p.x).reduce(math.max);
      return maxB.compareTo(maxA);
    });

  // Every bridge target used so far. Multiple holes converging on the exact
  // same vertex turns out to reliably defeat the ear-clipping pass
  // afterwards (even though each individual bridge is, in isolation,
  // perfectly valid) — so when a hole's natural ray-cast target has already
  // been claimed, retry with the ray tilted by a small alternating angle
  // (0, +Δ, -Δ, +2Δ, -2Δ, ...) until it lands on a fresh vertex. This
  // doesn't weaken the visibility guarantee the ray-cast itself gives,
  // since [_findBridgeTarget] is re-run in full against the tilted geometry
  // each time, not just nudged after the fact.
  final usedTargets = <Vec2>{};

  for (final rawHole in sortedHoles) {
    if (rawHole.length < 3) continue;
    var hole = List<Vec2>.from(rawHole);
    if (signedArea(hole) > 0) hole = hole.reversed.toList(); // must be CW inside a CCW outer

    var mIdx = 0;
    for (var i = 1; i < hole.length; i++) {
      if (hole[i].x > hole[mIdx].x) mIdx = i;
    }
    final m = hole[mIdx];

    var chosen = 0;
    for (var attempt = 0; attempt < 60; attempt++) {
      final magnitude = 0.05 * ((attempt + 1) ~/ 2);
      final theta = attempt == 0 ? 0.0 : (attempt.isOdd ? magnitude : -magnitude);
      final cosT = math.cos(theta);
      final sinT = math.sin(theta);
      final tiltedWorking = [for (final p in working) _rotate(p, cosT, sinT)];
      final tiltedM = _rotate(m, cosT, sinT);
      chosen = _findBridgeTarget(tiltedM, tiltedWorking);
      if (!usedTargets.contains(working[chosen])) break;
    }
    usedTargets.add(working[chosen]);
    final rotatedHole = [for (var k = 0; k < hole.length; k++) hole[(mIdx + k) % hole.length]];
    final bridgeStart = working[chosen];

    final spliced = <Vec2>[];
    for (var i = 0; i <= chosen; i++) {
      spliced.add(working[i]);
    }
    spliced.addAll(rotatedHole);
    spliced.add(m);
    spliced.add(bridgeStart);
    for (var i = chosen + 1; i < working.length; i++) {
      spliced.add(working[i]);
    }
    working = spliced;
  }

  return working;
}

/// Ear-clipping triangulation of a simple (possibly already hole-bridged)
/// polygon. Returns triangles as index triples into [pts]. Robust to the
/// zero-area duplicate-vertex bridge seams [mergeHolesIntoOuter] produces.
List<List<int>> earClipTriangulate(List<Vec2> pts) {
  final n = pts.length;
  if (n < 3) return [];

  final area = signedArea(pts);
  var order = List<int>.generate(n, (i) => i);
  if (area < 0) order = order.reversed.toList();

  final triangles = <List<int>>[];
  var remaining = order;
  var guard = 0;
  while (remaining.length > 3 && guard < n * n + 16) {
    guard++;
    var clippedIndex = -1;
    for (var i = 0; i < remaining.length; i++) {
      final iPrev = remaining[(i - 1 + remaining.length) % remaining.length];
      final iCurr = remaining[i];
      final iNext = remaining[(i + 1) % remaining.length];
      final a = pts[iPrev];
      final b = pts[iCurr];
      final c = pts[iNext];
      if (_cross(a, b, c) <= 1e-9) continue;

      // Both checks below exclude by INDEX (this candidate ear's own three
      // corners / edges), never by coordinate — bridging deliberately
      // creates several pairs of vertices that share a position (a hole's
      // rightmost point and its bridge target each appear twice), and those
      // are topologically distinct places in the boundary that must still
      // be checked against, not waved through because they look identical.
      var containsOther = false;
      for (final j in remaining) {
        if (j == iPrev || j == iCurr || j == iNext) continue;
        if (_pointStrictlyInsideTriangle(pts[j], a, b, c)) {
          containsOther = true;
          break;
        }
      }
      if (containsOther) continue;

      // Vertex-containment alone isn't sufficient once holes have been
      // bridged into the boundary: the "ear"'s closing diagonal (a -> c)
      // can cut across a hole/slit edge without any vertex happening to
      // fall inside the triangle. Reject that case too, or clipping it
      // would carve out (or double up) area that doesn't belong to it.
      var diagonalCrossesEdge = false;
      for (var k = 0; k < remaining.length; k++) {
        final e1 = remaining[k];
        final e2 = remaining[(k + 1) % remaining.length];
        if ((e1 == iPrev && e2 == iCurr) || (e1 == iCurr && e2 == iNext)) continue;
        if (_properlyIntersect(a, c, pts[e1], pts[e2])) {
          diagonalCrossesEdge = true;
          break;
        }
      }
      if (diagonalCrossesEdge) continue;

      triangles.add([iPrev, iCurr, iNext]);
      clippedIndex = i;
      break;
    }

    if (clippedIndex == -1) {
      // No candidate passed both checks — pick the smallest convex,
      // vertex-containment-clean ear we can find (ignoring the diagonal
      // check as a last resort) rather than the most-convex one: a small
      // local ear is far less likely to overlap distant geometry than the
      // sweeping triangle "most convex" tends to produce, which is what was
      // silently corrupting the total area on complex, multi-hole shapes.
      var bestI = -1;
      var bestArea = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final iPrev = remaining[(i - 1 + remaining.length) % remaining.length];
        final iCurr = remaining[i];
        final iNext = remaining[(i + 1) % remaining.length];
        final a = pts[iPrev];
        final b = pts[iCurr];
        final c = pts[iNext];
        if (_cross(a, b, c) <= 1e-9) continue;
        var containsOther = false;
        for (final j in remaining) {
          if (j == iPrev || j == iCurr || j == iNext) continue;
          if (_pointStrictlyInsideTriangle(pts[j], a, b, c)) {
            containsOther = true;
            break;
          }
        }
        if (containsOther) continue;
        final area = triangleArea(a, b, c);
        if (area < bestArea) {
          bestArea = area;
          bestI = i;
        }
      }
      // Truly nothing is even locally convex-and-clean (shouldn't happen
      // for a valid simple polygon) — fall back to the most-convex vertex
      // just to guarantee the loop terminates.
      if (bestI == -1) {
        var bestCross = double.negativeInfinity;
        for (var i = 0; i < remaining.length; i++) {
          final iPrev = remaining[(i - 1 + remaining.length) % remaining.length];
          final iCurr = remaining[i];
          final iNext = remaining[(i + 1) % remaining.length];
          final cr = _cross(pts[iPrev], pts[iCurr], pts[iNext]);
          if (cr > bestCross) {
            bestCross = cr;
            bestI = i;
          }
        }
      }
      final iPrev = remaining[(bestI - 1 + remaining.length) % remaining.length];
      final iCurr = remaining[bestI];
      final iNext = remaining[(bestI + 1) % remaining.length];
      triangles.add([iPrev, iCurr, iNext]);
      clippedIndex = bestI;
    }

    remaining = [for (var i = 0; i < remaining.length; i++) if (i != clippedIndex) remaining[i]];
  }
  if (remaining.length == 3) {
    triangles.add([remaining[0], remaining[1], remaining[2]]);
  }

  return triangles
      .where((t) => triangleArea(pts[t[0]], pts[t[1]], pts[t[2]]) > 1e-6)
      .toList();
}
