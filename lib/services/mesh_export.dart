import '../geometry/mesh.dart';
import '../geometry/placed_entities.dart';
import '../models/box_project.dart';
import '../models/dxf_entity.dart';
import '../models/hole.dart';
import '../models/vec2.dart';
import 'template_library.dart';

List<Vec2> _closedLoopPoints(DxfEntity entity, {int arcSegments = 64}) {
  final pts = entity.toPoints(arcSegments: arcSegments);
  if (pts.length > 1 && pts.first == pts.last) {
    return pts.sublist(0, pts.length - 1);
  }
  return pts;
}

/// The box outline's largest-area entity is the plate's outer boundary
/// (in practice a single closed polyline); every *other* entity in the box
/// outline — e.g. a manufacturer enclosure's own mounting-flange holes,
/// bundled right alongside its outline — is a hole cut through the plate,
/// same as a user-added [Hole].
({List<Vec2> outer, List<List<Vec2>> ownHoles}) _splitBoxOutline(List<DxfEntity> boxOutline) {
  if (boxOutline.isEmpty) return (outer: <Vec2>[], ownHoles: <List<Vec2>>[]);
  DxfEntity? outerEntity;
  var bestArea = 0.0;
  for (final e in boxOutline) {
    final b = e.boundingBox;
    final area = b.width * b.height;
    if (area > bestArea) {
      bestArea = area;
      outerEntity = e;
    }
  }
  final ownHoles = [
    for (final e in boxOutline)
      if (!identical(e, outerEntity)) _closedLoopPoints(e, arcSegments: 48),
  ].where((pts) => pts.length >= 3).toList();
  return (outer: _closedLoopPoints(outerEntity!), ownHoles: ownHoles);
}

List<List<Vec2>> _holeBoundaries(List<Hole> holes) {
  final result = <List<Vec2>>[];
  for (final hole in holes) {
    for (final entity in hole.toEntities()) {
      final pts = _closedLoopPoints(entity, arcSegments: 48);
      if (pts.length >= 3) result.add(pts);
    }
  }
  return result;
}

/// Every round mounting hole baked into each placed controller/power-supply
/// template's own geometry (already transformed by that instance's
/// position/rotation, and resized if it has a [PlacedTemplate.
/// holeDiameterOverride]) — these get physically mounted to the plate, so
/// their holes need to go all the way through it too.
List<List<Vec2>> _placedTemplateHoles(BoxProject project, TemplateLibrary library) {
  final result = <List<Vec2>>[];
  for (final placed in project.placedTemplates) {
    final template = library.byId(placed.templateId);
    if (template == null) continue;
    for (final entity in placedTemplateEntities(template, placed)) {
      if (entity is! DxfCircle) continue;
      final pts = _closedLoopPoints(entity, arcSegments: 48);
      if (pts.length >= 3) result.add(pts);
    }
  }
  return result;
}

/// Builds a solid-plate [Mesh] for [project]: the box outline extruded to
/// [thicknessMm], with every screw/zip-tie hole, every hole already baked
/// into the box template itself (e.g. a real enclosure's own mounting
/// flange holes), and every round mounting hole on a placed
/// controller/power-supply template cut all the way through.
Mesh buildPlateMesh(BoxProject project, TemplateLibrary library, {required double thicknessMm}) {
  final split = _splitBoxOutline(project.boxOutline);
  return extrudePlate(
    outer: split.outer,
    holes: [
      ...split.ownHoles,
      ..._holeBoundaries(project.holes),
      ..._placedTemplateHoles(project, library),
    ],
    thickness: thicknessMm,
  );
}
