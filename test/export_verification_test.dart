// Builds a sample project (placed template + a screw hole + a zip-tie hole)
// and writes the DXF/PDF exports to disk under build/, so their content can
// be inspected directly rather than only checked through the save dialog.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/models/box_project.dart';
import 'package:box_design_flutter/models/hole.dart';
import 'package:box_design_flutter/models/placed_template.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/services/dxf_export.dart';
import 'package:box_design_flutter/services/pdf_export.dart';
import 'package:box_design_flutter/services/stl_export.dart';
import 'package:box_design_flutter/services/template_library.dart';
import 'package:box_design_flutter/services/threemf_export.dart';

void main() {
  test('exports a sample project to real .dxf and .pdf files', () async {
    final assetJson = File('assets/templates/cg1500_placeholder.json').readAsStringSync();
    final library = TemplateLibrary();
    final template = library.importJson(assetJson);

    final project = BoxProject(
      name: 'verify_export',
      boxOutline: defaultRectangleOutline(width: 200, height: 120),
      placedTemplates: [
        PlacedTemplate(id: 'p1', templateId: template.id, position: const Vec2(10, 5)),
      ],
      holes: [
        Hole(id: 'h1', type: HoleType.screw, position: const Vec2(190, 5), diameter: 4.5),
        Hole(id: 'h2', type: HoleType.zipTie, position: const Vec2(100, 115), slotLength: 15, slotWidth: 4, rotationDeg: 90),
      ],
    );

    Directory('build').createSync(recursive: true);

    final dxfBytes = exportProjectAsDxfBytes(project, library);
    File('build/verify_export.dxf').writeAsBytesSync(dxfBytes);
    expect(dxfBytes.length, greaterThan(0));

    final pdfBytes = await exportProjectAsPdfBytes(project, library);
    File('build/verify_export.pdf').writeAsBytesSync(pdfBytes);
    expect(pdfBytes.length, greaterThan(0));
    // %PDF header magic bytes.
    expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);

    final stlBytes = exportProjectAsStlBytes(project, library, thicknessMm: 3);
    File('build/verify_export.stl').writeAsBytesSync(stlBytes);
    final stlText = utf8.decode(stlBytes);
    expect(stlText, startsWith('solid box_design'));
    expect(stlText.trim(), endsWith('endsolid box_design'));
    expect('facet normal'.allMatches(stlText).length, greaterThan(0));

    final threemfBytes = exportProjectAs3mfBytes(project, library, thicknessMm: 3);
    File('build/verify_export.3mf').writeAsBytesSync(threemfBytes);
    // ZIP local-file-header magic bytes (PK\x03\x04).
    expect(threemfBytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
  });
}
