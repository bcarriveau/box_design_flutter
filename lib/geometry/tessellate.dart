import 'dart:ui';

import '../models/dxf_entity.dart';
import '../models/vec2.dart';

/// Builds a Flutter [Path] from mm-space entities, in the entities' own
/// (math, Y-up) coordinate system. Callers that paint on a Y-down canvas
/// should apply a Y-flip transform, not bake it into the geometry.
Path entitiesToPath(List<DxfEntity> entities) {
  final path = Path();
  for (final entity in entities) {
    final points = entity.toPoints();
    if (points.isEmpty) continue;
    path.moveTo(points.first.x, points.first.y);
    for (final p in points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
  }
  return path;
}

BoundingBox entitiesBoundingBox(List<DxfEntity> entities) {
  BoundingBox? box;
  for (final e in entities) {
    box = BoundingBox.merge(box, e.boundingBox);
  }
  return box ?? const BoundingBox(0, 0, 0, 0);
}
