import '../models/controller_template.dart';
import '../models/dxf_entity.dart';
import '../models/placed_template.dart';
import 'transform.dart';

/// [template]'s geometry as placed by [placed]: its position/rotation
/// transform applied, and — if set — [PlacedTemplate.holeDiameterOverride]
/// resizing every round mounting hole baked into the template first.
List<DxfEntity> placedTemplateEntities(ControllerTemplate template, PlacedTemplate placed) {
  final override = placed.holeDiameterOverride;
  final baseEntities = override == null
      ? template.entities
      : [
          for (final e in template.entities)
            if (e is DxfCircle) DxfCircle(e.center, override / 2) else e,
        ];
  return placeEntities(baseEntities, delta: placed.position, rotationDeg: placed.rotationDeg);
}
