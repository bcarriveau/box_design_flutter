import 'dart:math' as math;

import '../geometry/placed_entities.dart';
import '../models/vec2.dart';
import 'design_controller.dart';

/// Snaps [raw] (box-space mm) to the nearest hole center, placed-template
/// origin, or point along any box/template edge within [toleranceMm] --
/// lets the measure tool click precisely on existing geometry ("two lines
/// or holes") instead of an approximate freehand point. Returns [raw]
/// unchanged if nothing is within tolerance.
Vec2 snapPoint(Vec2 raw, DesignController controller, {double toleranceMm = 3.0}) {
  final project = controller.project;
  Vec2? best;
  var bestDist = toleranceMm;

  void consider(Vec2 candidate) {
    final dx = candidate.x - raw.x;
    final dy = candidate.y - raw.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < bestDist) {
      bestDist = dist;
      best = candidate;
    }
  }

  void considerEdges(Iterable<Vec2> points) {
    Vec2? prev;
    for (final p in points) {
      if (prev != null) consider(_nearestOnSegment(prev, p, raw));
      prev = p;
    }
  }

  for (final hole in project.holes) {
    consider(hole.position);
  }
  for (final placed in project.placedTemplates) {
    consider(placed.position);
    final template = controller.library.byId(placed.templateId);
    if (template == null) continue;
    final entities = placedTemplateEntities(template, placed);
    for (final entity in entities) {
      considerEdges(entity.toPoints());
    }
  }
  for (final entity in project.boxOutline) {
    considerEdges(entity.toPoints());
  }

  return best ?? raw;
}

Vec2 _nearestOnSegment(Vec2 a, Vec2 b, Vec2 p) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final lenSq = abx * abx + aby * aby;
  if (lenSq < 1e-12) return a;
  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lenSq;
  t = t.clamp(0.0, 1.0);
  return Vec2(a.x + abx * t, a.y + aby * t);
}
