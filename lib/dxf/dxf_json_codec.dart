import '../models/dxf_entity.dart';
import '../models/vec2.dart';

/// Our own proprietary template geometry format: a plain JSON list of
/// entities, independent of the DXF text format. This is what gets stored
/// in bundled template assets, imported (from DXF) templates, and (later)
/// templates fetched from a remote repo.
List<Map<String, dynamic>> entitiesToJson(List<DxfEntity> entities) {
  return entities.map(_entityToJson).toList();
}

List<DxfEntity> entitiesFromJson(List<dynamic> json) {
  return json.map((e) => _entityFromJson(e as Map<String, dynamic>)).toList();
}

Map<String, dynamic> _entityToJson(DxfEntity entity) {
  return switch (entity) {
    DxfLine e => {
        'type': 'line',
        'start': e.start.toJson(),
        'end': e.end.toJson(),
      },
    DxfCircle e => {
        'type': 'circle',
        'center': e.center.toJson(),
        'radius': e.radius,
      },
    DxfArc e => {
        'type': 'arc',
        'center': e.center.toJson(),
        'radius': e.radius,
        'startAngle': e.startAngleDeg,
        'endAngle': e.endAngleDeg,
      },
    DxfPolyline e => {
        'type': 'polyline',
        'closed': e.closed,
        'vertices': e.vertices
            .map((v) => {'x': v.point.x, 'y': v.point.y, 'bulge': v.bulge})
            .toList(),
      },
  };
}

DxfEntity _entityFromJson(Map<String, dynamic> json) {
  switch (json['type'] as String) {
    case 'line':
      return DxfLine(
        Vec2.fromJson(json['start'] as Map<String, dynamic>),
        Vec2.fromJson(json['end'] as Map<String, dynamic>),
      );
    case 'circle':
      return DxfCircle(
        Vec2.fromJson(json['center'] as Map<String, dynamic>),
        (json['radius'] as num).toDouble(),
      );
    case 'arc':
      return DxfArc(
        Vec2.fromJson(json['center'] as Map<String, dynamic>),
        (json['radius'] as num).toDouble(),
        (json['startAngle'] as num).toDouble(),
        (json['endAngle'] as num).toDouble(),
      );
    case 'polyline':
      final vertices = (json['vertices'] as List<dynamic>)
          .map((v) => PolyVertex(
                Vec2((v['x'] as num).toDouble(), (v['y'] as num).toDouble()),
                bulge: ((v['bulge'] as num?) ?? 0).toDouble(),
              ))
          .toList();
      return DxfPolyline(vertices, closed: json['closed'] as bool? ?? false);
    default:
      throw FormatException('Unknown entity type: ${json['type']}');
  }
}
