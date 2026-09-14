import '../dxf/dxf_json_codec.dart';
import '../geometry/tessellate.dart';
import 'dxf_entity.dart';
import 'hole.dart';
import 'placed_template.dart';
import 'vec2.dart';

/// A simple rectangular fallback outline, used before any real box template
/// has loaded.
List<DxfEntity> defaultRectangleOutline({double width = 150, double height = 90}) {
  return [
    DxfPolyline([
      const PolyVertex(Vec2(0, 0)),
      PolyVertex(Vec2(width, 0)),
      PolyVertex(Vec2(width, height)),
      PolyVertex(Vec2(0, height)),
    ], closed: true),
  ];
}

class BoxProject {
  final String name;

  /// Which box template this outline came from (for display only).
  final String? boxTemplateId;

  /// The enclosure outline, normalized so its bounding box's min corner is
  /// at (0, 0) — everything else (placed templates, holes) is positioned
  /// relative to that.
  final List<DxfEntity> boxOutline;

  final List<PlacedTemplate> placedTemplates;
  final List<Hole> holes;

  BoxProject({
    this.name = 'Untitled Box',
    this.boxTemplateId,
    List<DxfEntity>? boxOutline,
    this.placedTemplates = const [],
    this.holes = const [],
  }) : boxOutline = boxOutline ?? defaultRectangleOutline();

  BoundingBox get boxBoundingBox => entitiesBoundingBox(boxOutline);
  double get boxWidth => boxBoundingBox.width;
  double get boxHeight => boxBoundingBox.height;

  BoxProject copyWith({
    String? name,
    String? boxTemplateId,
    List<DxfEntity>? boxOutline,
    List<PlacedTemplate>? placedTemplates,
    List<Hole>? holes,
  }) {
    return BoxProject(
      name: name ?? this.name,
      boxTemplateId: boxTemplateId ?? this.boxTemplateId,
      boxOutline: boxOutline ?? this.boxOutline,
      placedTemplates: placedTemplates ?? this.placedTemplates,
      holes: holes ?? this.holes,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'boxTemplateId': boxTemplateId,
        'boxOutline': entitiesToJson(boxOutline),
        'placedTemplates': placedTemplates.map((p) => p.toJson()).toList(),
        'holes': holes.map((h) => h.toJson()).toList(),
      };

  factory BoxProject.fromJson(Map<String, dynamic> json) => BoxProject(
        name: json['name'] as String? ?? 'Untitled Box',
        boxTemplateId: json['boxTemplateId'] as String?,
        boxOutline: json['boxOutline'] != null
            ? entitiesFromJson(json['boxOutline'] as List<dynamic>)
            : defaultRectangleOutline(
                width: (json['boxWidth'] as num?)?.toDouble() ?? 150,
                height: (json['boxHeight'] as num?)?.toDouble() ?? 90,
              ),
        placedTemplates: (json['placedTemplates'] as List<dynamic>? ?? [])
            .map((p) => PlacedTemplate.fromJson(p as Map<String, dynamic>))
            .toList(),
        holes: (json['holes'] as List<dynamic>? ?? [])
            .map((h) => Hole.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}
