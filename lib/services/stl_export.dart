import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/mesh.dart';
import '../models/box_project.dart';
import 'mesh_export.dart';
import 'template_library.dart';

Vec3 _triangleNormal(Vec3 a, Vec3 b, Vec3 c) {
  final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;
  final len = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (len < 1e-12) return const Vec3(0, 0, 1);
  return Vec3(nx / len, ny / len, nz / len);
}

String _f(double v) => v.toStringAsFixed(6);

/// Renders [mesh] as an ASCII STL. ASCII (rather than binary) keeps the
/// writer simple and the files here are small (a few hundred triangles at
/// most), so the size cost doesn't matter.
String meshToStlText(Mesh mesh, {String solidName = 'box_design'}) {
  final buffer = StringBuffer();
  buffer.writeln('solid $solidName');
  for (final t in mesh.triangles) {
    final a = mesh.vertices[t[0]];
    final b = mesh.vertices[t[1]];
    final c = mesh.vertices[t[2]];
    final n = _triangleNormal(a, b, c);
    buffer.writeln('facet normal ${_f(n.x)} ${_f(n.y)} ${_f(n.z)}');
    buffer.writeln('  outer loop');
    buffer.writeln('    vertex ${_f(a.x)} ${_f(a.y)} ${_f(a.z)}');
    buffer.writeln('    vertex ${_f(b.x)} ${_f(b.y)} ${_f(b.z)}');
    buffer.writeln('    vertex ${_f(c.x)} ${_f(c.y)} ${_f(c.z)}');
    buffer.writeln('  endloop');
    buffer.writeln('endfacet');
  }
  buffer.writeln('endsolid $solidName');
  return buffer.toString();
}

Uint8List exportProjectAsStlBytes(
  BoxProject project,
  TemplateLibrary library, {
  double thicknessMm = 5.0,
  bool addStandoffs = false,
  double standoffHeight = 3,
  double standoffWallThickness = 2,
}) {
  final mesh = buildPlateMesh(
    project,
    library,
    thicknessMm: thicknessMm,
    addStandoffs: addStandoffs,
    standoffHeight: standoffHeight,
    standoffWallThickness: standoffWallThickness,
  );
  return Uint8List.fromList(utf8.encode(meshToStlText(mesh)));
}
