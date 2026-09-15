import 'dart:convert';
import 'dart:typed_data';

import '../dxf/dxf_writer.dart';
import '../geometry/placed_entities.dart';
import '../models/box_project.dart';
import '../models/dxf_entity.dart';
import 'template_library.dart';

/// Flattens a [BoxProject] into a single absolute-coordinate entity list:
/// the box outline, every placed template's geometry (transformed by its
/// position/rotation), and every hole's cut geometry.
List<DxfEntity> assembleProjectEntities(BoxProject project, TemplateLibrary library) {
  final entities = <DxfEntity>[...project.boxOutline];

  for (final placed in project.placedTemplates) {
    final template = library.byId(placed.templateId);
    if (template == null) continue;
    entities.addAll(placedTemplateEntities(template, placed));
  }

  for (final hole in project.holes) {
    entities.addAll(hole.toEntities());
  }

  return entities;
}

Uint8List exportProjectAsDxfBytes(BoxProject project, TemplateLibrary library) {
  final entities = assembleProjectEntities(project, library);
  return Uint8List.fromList(utf8.encode(writeDxf(entities)));
}
