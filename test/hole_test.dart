import 'package:flutter_test/flutter_test.dart';
import 'package:box_design_flutter/models/hole.dart';
import 'package:box_design_flutter/models/vec2.dart';

void main() {
  test('screw hole produces a single circle of the right size', () {
    final hole = Hole(id: '1', type: HoleType.screw, position: const Vec2(10, 20), diameter: 6);
    final box = hole.boundingBox;
    expect(box.width, closeTo(6, 1e-9));
    expect(box.height, closeTo(6, 1e-9));
    expect(box.center.x, closeTo(10, 1e-9));
    expect(box.center.y, closeTo(20, 1e-9));
  });

  test('zip-tie slot bounding box matches length x width, centered on position', () {
    final hole = Hole(
      id: '2',
      type: HoleType.zipTie,
      position: const Vec2(0, 0),
      slotLength: 12,
      slotWidth: 4,
    );
    final box = hole.boundingBox;
    expect(box.width, closeTo(12, 0.05));
    expect(box.height, closeTo(4, 0.05));
  });

  test('zip-tie slot rotates 90 degrees, swapping the bounding box dimensions', () {
    final hole = Hole(
      id: '3',
      type: HoleType.zipTie,
      position: const Vec2(0, 0),
      slotLength: 12,
      slotWidth: 4,
      rotationDeg: 90,
    );
    final box = hole.boundingBox;
    expect(box.width, closeTo(4, 0.05));
    expect(box.height, closeTo(12, 0.05));
  });
}
