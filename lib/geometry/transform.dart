import '../models/dxf_entity.dart';
import '../models/vec2.dart';

List<DxfEntity> placeEntities(
  List<DxfEntity> entities, {
  Vec2 delta = const Vec2(0, 0),
  double rotationDeg = 0,
  Vec2 pivot = const Vec2(0, 0),
}) {
  return entities
      .map((e) => e.transformed(delta: delta, rotationDeg: rotationDeg, pivot: pivot))
      .toList();
}
