import 'dart:math' as math;

/// A point/vector in millimeter space.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  Vec2 translated(double dx, double dy) => Vec2(x + dx, y + dy);

  Vec2 add(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 subtract(Vec2 other) => Vec2(x - other.x, y - other.y);

  /// Rotate this point by [degrees] around [pivot] (counter-clockwise, math convention).
  Vec2 rotated(double degrees, {Vec2 pivot = const Vec2(0, 0)}) {
    if (degrees == 0) return this;
    final rad = degrees * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    final dx = x - pivot.x;
    final dy = y - pivot.y;
    return Vec2(
      pivot.x + dx * cosA - dy * sinA,
      pivot.y + dx * sinA + dy * cosA,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Vec2.fromJson(Map<String, dynamic> json) =>
      Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  @override
  String toString() => 'Vec2($x, $y)';

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class BoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const BoundingBox(this.minX, this.minY, this.maxX, this.maxY);

  double get width => maxX - minX;
  double get height => maxY - minY;
  Vec2 get center => Vec2((minX + maxX) / 2, (minY + maxY) / 2);

  static BoundingBox? merge(BoundingBox? a, BoundingBox? b) {
    if (a == null) return b;
    if (b == null) return a;
    return BoundingBox(
      math.min(a.minX, b.minX),
      math.min(a.minY, b.minY),
      math.max(a.maxX, b.maxX),
      math.max(a.maxY, b.maxY),
    );
  }

  static BoundingBox fromPoints(Iterable<Vec2> points) {
    double? minX, minY, maxX, maxY;
    for (final p in points) {
      minX = minX == null ? p.x : math.min(minX, p.x);
      minY = minY == null ? p.y : math.min(minY, p.y);
      maxX = maxX == null ? p.x : math.max(maxX, p.x);
      maxY = maxY == null ? p.y : math.max(maxY, p.y);
    }
    if (minX == null) return const BoundingBox(0, 0, 0, 0);
    return BoundingBox(minX, minY!, maxX!, maxY!);
  }
}
