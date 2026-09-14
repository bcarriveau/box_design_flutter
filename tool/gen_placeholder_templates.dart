// Run with: dart run tool/gen_placeholder_templates.dart
// Regenerates the bundled placeholder template JSON assets.
import 'dart:convert';
import 'dart:io';

import 'package:box_design_flutter/dxf/dxf_json_codec.dart';
import 'package:box_design_flutter/models/dxf_entity.dart';
import 'package:box_design_flutter/models/vec2.dart';

List<DxfEntity> rectangleWithCornerHoles({
  required double width,
  required double height,
  required double holeInset,
  required double holeDiameter,
}) {
  final outline = DxfPolyline([
    const PolyVertex(Vec2(0, 0)),
    PolyVertex(Vec2(width, 0)),
    PolyVertex(Vec2(width, height)),
    PolyVertex(Vec2(0, height)),
  ], closed: true);

  final holeCenters = [
    Vec2(holeInset, holeInset),
    Vec2(width - holeInset, holeInset),
    Vec2(width - holeInset, height - holeInset),
    Vec2(holeInset, height - holeInset),
  ];

  return [
    outline,
    for (final c in holeCenters) DxfCircle(c, holeDiameter / 2),
  ];
}

void writeTemplate(String fileName, String id, String name, String category, List<DxfEntity> entities) {
  final json = {
    'id': id,
    'name': name,
    'category': category,
    'entities': entitiesToJson(entities),
  };
  final file = File('assets/templates/$fileName');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln('Wrote ${file.path}');
}

void main() {
  // All PLACEHOLDER geometry — replace by importing real DXFs over these
  // ids once available; everything downstream treats them like any other
  // template.
  writeTemplate(
    'cg1500_placeholder.json',
    'cg1500_placeholder',
    'CG-1500 Enclosure (placeholder)',
    'box',
    rectangleWithCornerHoles(width: 250, height: 150, holeInset: 8, holeDiameter: 4),
  );

  writeTemplate(
    'box_small_placeholder.json',
    'box_small_placeholder',
    'Small Enclosure (placeholder)',
    'box',
    rectangleWithCornerHoles(width: 150, height: 90, holeInset: 6, holeDiameter: 4),
  );

  writeTemplate(
    'controller_generic_placeholder.json',
    'controller_generic_placeholder',
    'Generic Controller Board (placeholder)',
    'controller',
    rectangleWithCornerHoles(width: 172, height: 111, holeInset: 6, holeDiameter: 3.5),
  );

  writeTemplate(
    'power_supply_generic_placeholder.json',
    'power_supply_generic_placeholder',
    'Generic Power Supply (placeholder)',
    'powerSupply',
    rectangleWithCornerHoles(width: 115, height: 50, holeInset: 5, holeDiameter: 4),
  );
}
