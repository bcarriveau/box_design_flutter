import '../dxf/dxf_json_codec.dart';
import '../geometry/tessellate.dart';
import 'dxf_entity.dart';
import 'vec2.dart';

enum TemplateSource { builtIn, imported, remote, userMade }

/// Which section of the palette a template belongs to. [box] templates are
/// applied as the enclosure outline itself (one active at a time); the
/// others are placed as items inside the box. [controllerAddon] is a
/// daughterboard/expansion board that mounts alongside a controller (e.g. an
/// output-expansion or differential board); [powerDistribution] is a
/// terminal-block/fuse-style board that distributes power rather than a
/// self-contained supply brick like [powerSupply].
enum TemplateCategory { box, controller, controllerAddon, powerSupply, powerDistribution, receiver }

/// A reusable footprint: a rigid-body bag of geometry (outline, mounting
/// holes, silkscreen, whatever the source DXF contained), stored in the
/// template's own local coordinate space with its bounding box's min corner
/// at roughly (0, 0).
class ControllerTemplate {
  final String id;
  final String name;
  final List<DxfEntity> entities;
  final TemplateSource source;
  final TemplateCategory category;

  ControllerTemplate({
    required this.id,
    required this.name,
    required this.entities,
    required this.source,
    required this.category,
  });

  BoundingBox get boundingBox => entitiesBoundingBox(entities);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'entities': entitiesToJson(entities),
      };

  factory ControllerTemplate.fromJson(Map<String, dynamic> json, {required TemplateSource source}) {
    return ControllerTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      entities: entitiesFromJson(json['entities'] as List<dynamic>),
      source: source,
      category: TemplateCategory.values.byName(json['category'] as String? ?? 'controller'),
    );
  }
}
