import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../geometry/mesh.dart';
import '../models/box_project.dart';
import 'mesh_export.dart';
import 'template_library.dart';

const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>
''';

const String _relsXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rel0" Target="/3D/3dmodel.model" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>
''';

String _f(double v) => v.toStringAsFixed(4);

String meshTo3mfModelXml(Mesh mesh) {
  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">');
  buffer.writeln('  <resources>');
  buffer.writeln('    <object id="1" type="model">');
  buffer.writeln('      <mesh>');
  buffer.writeln('        <vertices>');
  for (final v in mesh.vertices) {
    buffer.writeln('          <vertex x="${_f(v.x)}" y="${_f(v.y)}" z="${_f(v.z)}"/>');
  }
  buffer.writeln('        </vertices>');
  buffer.writeln('        <triangles>');
  for (final t in mesh.triangles) {
    buffer.writeln('          <triangle v1="${t[0]}" v2="${t[1]}" v3="${t[2]}"/>');
  }
  buffer.writeln('        </triangles>');
  buffer.writeln('      </mesh>');
  buffer.writeln('    </object>');
  buffer.writeln('  </resources>');
  buffer.writeln('  <build>');
  buffer.writeln('    <item objectid="1"/>');
  buffer.writeln('  </build>');
  buffer.writeln('</model>');
  return buffer.toString();
}

Uint8List exportProjectAs3mfBytes(BoxProject project, TemplateLibrary library, {double thicknessMm = 5.0}) {
  final mesh = buildPlateMesh(project, library, thicknessMm: thicknessMm);

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml))
    ..addFile(ArchiveFile.string('_rels/.rels', _relsXml))
    ..addFile(ArchiveFile.string('3D/3dmodel.model', meshTo3mfModelXml(mesh)));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
