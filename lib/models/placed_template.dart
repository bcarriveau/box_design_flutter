import 'vec2.dart';

/// An instance of a [ControllerTemplate] placed on the enclosure, at
/// [position] (mm, maps to the template's local origin) and rotated by
/// [rotationDeg] (degrees, counter-clockwise) about that origin.
class PlacedTemplate {
  final String id;
  final String templateId;
  final Vec2 position;
  final double rotationDeg;

  const PlacedTemplate({
    required this.id,
    required this.templateId,
    required this.position,
    this.rotationDeg = 0,
  });

  PlacedTemplate copyWith({Vec2? position, double? rotationDeg}) => PlacedTemplate(
        id: id,
        templateId: templateId,
        position: position ?? this.position,
        rotationDeg: rotationDeg ?? this.rotationDeg,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'position': position.toJson(),
        'rotationDeg': rotationDeg,
      };

  factory PlacedTemplate.fromJson(Map<String, dynamic> json) => PlacedTemplate(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        position: Vec2.fromJson(json['position'] as Map<String, dynamic>),
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
      );
}
