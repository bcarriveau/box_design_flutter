import 'dart:math' as math;

import 'vec2.dart';

/// Internal geometry model shared by DXF import/export, our own JSON
/// template format, and on-canvas rendering. Coordinates are in millimeters.
sealed class DxfEntity {
  const DxfEntity();

  /// Returns a copy of this entity translated by [delta] and then rotated by
  /// [rotationDeg] (degrees, counter-clockwise) around [pivot].
  DxfEntity transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  });

  /// Approximates this entity as a polyline of points, in mm, for painting
  /// and hit-testing. Arcs/circles are flattened using [arcSegments] points
  /// per full circle.
  List<Vec2> toPoints({int arcSegments = 64});

  BoundingBox get boundingBox => BoundingBox.fromPoints(toPoints());
}

class DxfLine extends DxfEntity {
  final Vec2 start;
  final Vec2 end;

  const DxfLine(this.start, this.end);

  @override
  DxfLine transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  }) {
    return DxfLine(
      start.rotated(rotationDeg, pivot: pivot).add(delta),
      end.rotated(rotationDeg, pivot: pivot).add(delta),
    );
  }

  @override
  List<Vec2> toPoints({int arcSegments = 64}) => [start, end];
}

class DxfCircle extends DxfEntity {
  final Vec2 center;
  final double radius;

  const DxfCircle(this.center, this.radius);

  @override
  DxfCircle transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  }) {
    return DxfCircle(center.rotated(rotationDeg, pivot: pivot).add(delta), radius);
  }

  @override
  List<Vec2> toPoints({int arcSegments = 64}) {
    final points = <Vec2>[];
    for (var i = 0; i <= arcSegments; i++) {
      final theta = 2 * math.pi * i / arcSegments;
      points.add(Vec2(
        center.x + radius * math.cos(theta),
        center.y + radius * math.sin(theta),
      ));
    }
    return points;
  }
}

/// Arc from [startAngleDeg] to [endAngleDeg], counter-clockwise, degrees
/// measured the standard DXF way (0 = +X axis).
class DxfArc extends DxfEntity {
  final Vec2 center;
  final double radius;
  final double startAngleDeg;
  final double endAngleDeg;

  const DxfArc(this.center, this.radius, this.startAngleDeg, this.endAngleDeg);

  @override
  DxfArc transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  }) {
    return DxfArc(
      center.rotated(rotationDeg, pivot: pivot).add(delta),
      radius,
      startAngleDeg + rotationDeg,
      endAngleDeg + rotationDeg,
    );
  }

  @override
  List<Vec2> toPoints({int arcSegments = 64}) {
    var sweep = endAngleDeg - startAngleDeg;
    while (sweep <= 0) {
      sweep += 360;
    }
    final segments = math.max(2, (arcSegments * sweep / 360).round());
    final points = <Vec2>[];
    for (var i = 0; i <= segments; i++) {
      final theta = (startAngleDeg + sweep * i / segments) * math.pi / 180.0;
      points.add(Vec2(
        center.x + radius * math.cos(theta),
        center.y + radius * math.sin(theta),
      ));
    }
    return points;
  }
}

/// A polyline vertex with an optional DXF-style bulge (tangent of a quarter
/// of the included angle of the arc leading to the *next* vertex; 0 = straight
/// segment).
class PolyVertex {
  final Vec2 point;
  final double bulge;

  const PolyVertex(this.point, {this.bulge = 0});

  PolyVertex transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  }) {
    return PolyVertex(point.rotated(rotationDeg, pivot: pivot).add(delta), bulge: bulge);
  }
}

class DxfPolyline extends DxfEntity {
  final List<PolyVertex> vertices;
  final bool closed;

  const DxfPolyline(this.vertices, {this.closed = false});

  @override
  DxfPolyline transformed({
    Vec2 delta = const Vec2(0, 0),
    double rotationDeg = 0,
    Vec2 pivot = const Vec2(0, 0),
  }) {
    return DxfPolyline(
      vertices
          .map((v) => v.transformed(delta: delta, rotationDeg: rotationDeg, pivot: pivot))
          .toList(),
      closed: closed,
    );
  }

  @override
  List<Vec2> toPoints({int arcSegments = 64}) {
    if (vertices.isEmpty) return [];
    final points = <Vec2>[];
    final segmentCount = closed ? vertices.length : vertices.length - 1;
    for (var i = 0; i < segmentCount; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      points.add(a.point);
      if (a.bulge != 0) {
        points.addAll(_bulgeArcPoints(a.point, b.point, a.bulge, arcSegments));
      }
    }
    points.add(closed ? vertices[0].point : vertices.last.point);
    return points;
  }

  /// Points strictly between [from] and [to] along the bulge arc (exclusive
  /// of the endpoints, which the caller already includes). bulge = tan(includedAngle / 4).
  static List<Vec2> _bulgeArcPoints(Vec2 from, Vec2 to, double bulge, int arcSegments) {
    final includedAngle = 4 * math.atan(bulge);
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final chord = math.sqrt(dx * dx + dy * dy);
    if (chord == 0 || includedAngle == 0) return [];
    final radius = chord / (2 * math.sin(includedAngle.abs() / 2));
    final len = chord;
    final perpX = -dy / len;
    final perpY = dx / len;
    final sign = bulge < 0 ? -1 : 1;
    final centerDist = radius * math.cos(includedAngle.abs() / 2) * sign;
    final center = Vec2((from.x + to.x) / 2 + perpX * centerDist, (from.y + to.y) / 2 + perpY * centerDist);

    final startAngle = math.atan2(from.y - center.y, from.x - center.x);
    final segments = math.max(1, (arcSegments * includedAngle.abs() / (2 * math.pi)).round());
    final points = <Vec2>[];
    for (var i = 1; i < segments; i++) {
      final theta = startAngle + includedAngle * i / segments;
      points.add(Vec2(
        center.x + radius * math.cos(theta),
        center.y + radius * math.sin(theta),
      ));
    }
    return points;
  }
}
