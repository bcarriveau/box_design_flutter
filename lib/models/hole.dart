import 'dart:math' as math;

import '../geometry/tessellate.dart';
import 'dxf_entity.dart';
import 'vec2.dart';

enum HoleType { screw, zipTie, slot }

/// A screw hole, zip-tie hole pair, or elongated slot placed directly in
/// box (global) space —
/// unlike [PlacedTemplate], holes are not reusable templates so they carry
/// their own absolute geometry parameters rather than a local origin.
class Hole {
  final String id;
  final HoleType type;
  final Vec2 position;
  final double rotationDeg;

  /// Diameter in mm, used when [type] is [HoleType.screw].
  final double diameter;

  /// Overall end-to-end span in mm between the two hole centers' outer
  /// edges, and the diameter of each hole, used when [type] is
  /// [HoleType.zipTie]. For [HoleType.slot], the overall length and width
  /// of a single elongated stadium-shaped slot instead.
  final double slotLength;
  final double slotWidth;

  const Hole({
    required this.id,
    required this.type,
    required this.position,
    this.rotationDeg = 0,
    this.diameter = 4.5,
    this.slotLength = 12,
    this.slotWidth = 4,
  });

  Hole copyWith({
    Vec2? position,
    double? rotationDeg,
    double? diameter,
    double? slotLength,
    double? slotWidth,
  }) {
    return Hole(
      id: id,
      type: type,
      position: position ?? this.position,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      diameter: diameter ?? this.diameter,
      slotLength: slotLength ?? this.slotLength,
      slotWidth: slotWidth ?? this.slotWidth,
    );
  }

  /// The hole's cut geometry, in absolute box-space mm coordinates.
  List<DxfEntity> toEntities() {
    if (type == HoleType.screw) {
      return [DxfCircle(position, diameter / 2)];
    }

    if (type == HoleType.zipTie) {
      // Two round holes with solid material left between them -- the wire
      // bundle lies across that bridge and a zip tie loops down through one
      // hole, over the wires, and back up through the other.
      final r = slotWidth / 2;
      final hl = math.max(0.0, slotLength / 2 - r);
      final local = <DxfEntity>[
        DxfCircle(Vec2(-hl, 0), r),
        DxfCircle(Vec2(hl, 0), r),
      ];
      return local
          .map((e) => e.transformed(delta: position, rotationDeg: rotationDeg))
          .toList();
    }

    // A single elongated stadium-shaped slot (e.g. for a screw with
    // adjustable position, or a wide zip-tie pass-through). One closed
    // polyline rather than separate line/arc entities, so hole-cutting code
    // that treats each hole boundary as one closed loop sees a continuous
    // slot instead of two disconnected end-cap semicircles with solid
    // material left between them.
    final outline = DxfPolyline(stadiumVertices(slotLength, slotWidth), closed: true);
    return [outline.transformed(delta: position, rotationDeg: rotationDeg)];
  }

  BoundingBox get boundingBox => entitiesBoundingBox(toEntities());

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'position': position.toJson(),
        'rotationDeg': rotationDeg,
        'diameter': diameter,
        'slotLength': slotLength,
        'slotWidth': slotWidth,
      };

  factory Hole.fromJson(Map<String, dynamic> json) => Hole(
        id: json['id'] as String,
        type: HoleType.values.byName(json['type'] as String),
        position: Vec2.fromJson(json['position'] as Map<String, dynamic>),
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        diameter: (json['diameter'] as num?)?.toDouble() ?? 4.5,
        slotLength: (json['slotLength'] as num?)?.toDouble() ?? 12,
        slotWidth: (json['slotWidth'] as num?)?.toDouble() ?? 4,
      );
}
