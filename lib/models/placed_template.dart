import 'vec2.dart';

/// An instance of a [ControllerTemplate] placed on the enclosure, at
/// [position] (mm, maps to the template's local origin) and rotated by
/// [rotationDeg] (degrees, counter-clockwise) about that origin.
class PlacedTemplate {
  final String id;
  final String templateId;
  final Vec2 position;
  final double rotationDeg;

  /// When set, overrides the diameter of every round mounting hole baked
  /// into the template's own geometry (a single "resize all the holes on
  /// this item" knob) — null means use the template's own hole size as-is.
  final double? holeDiameterOverride;

  const PlacedTemplate({
    required this.id,
    required this.templateId,
    required this.position,
    this.rotationDeg = 0,
    this.holeDiameterOverride,
  });

  PlacedTemplate copyWith({Vec2? position, double? rotationDeg}) => PlacedTemplate(
        id: id,
        templateId: templateId,
        position: position ?? this.position,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        holeDiameterOverride: holeDiameterOverride,
      );

  /// Sets (or, passing null, clears back to the template default) the
  /// mounting-hole diameter override. A separate method from [copyWith]
  /// since that can't tell "leave unchanged" apart from "clear to null".
  PlacedTemplate withHoleDiameterOverride(double? value) => PlacedTemplate(
        id: id,
        templateId: templateId,
        position: position,
        rotationDeg: rotationDeg,
        holeDiameterOverride: value,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'position': position.toJson(),
        'rotationDeg': rotationDeg,
        if (holeDiameterOverride != null) 'holeDiameterOverride': holeDiameterOverride,
      };

  factory PlacedTemplate.fromJson(Map<String, dynamic> json) => PlacedTemplate(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        position: Vec2.fromJson(json['position'] as Map<String, dynamic>),
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        holeDiameterOverride: (json['holeDiameterOverride'] as num?)?.toDouble(),
      );
}
