import '../models/dxf_entity.dart';

/// Writes a minimal, valid ASCII DXF R12 file: a HEADER section (just enough
/// for CAD/CAM tools to recognize units) and an ENTITIES section. No
/// TABLES/BLOCKS section is needed since entities default to layer "0",
/// which always exists implicitly.
String writeDxf(List<DxfEntity> entities) {
  final buffer = StringBuffer();

  void pair(int code, Object value) {
    buffer.writeln(code);
    buffer.writeln(value);
  }

  pair(0, 'SECTION');
  pair(2, 'HEADER');
  pair(9, r'$ACADVER');
  pair(1, 'AC1009');
  pair(9, r'$INSUNITS');
  pair(70, 4); // 4 = millimeters
  pair(0, 'ENDSEC');

  pair(0, 'SECTION');
  pair(2, 'ENTITIES');
  for (final entity in entities) {
    _writeEntity(pair, entity);
  }
  pair(0, 'ENDSEC');
  pair(0, 'EOF');

  return buffer.toString();
}

String _fmt(double v) => v.toStringAsFixed(6);

void _writeEntity(void Function(int, Object) pair, DxfEntity entity) {
  switch (entity) {
    case DxfLine e:
      pair(0, 'LINE');
      pair(8, '0');
      pair(10, _fmt(e.start.x));
      pair(20, _fmt(e.start.y));
      pair(30, '0.0');
      pair(11, _fmt(e.end.x));
      pair(21, _fmt(e.end.y));
      pair(31, '0.0');
    case DxfCircle e:
      pair(0, 'CIRCLE');
      pair(8, '0');
      pair(10, _fmt(e.center.x));
      pair(20, _fmt(e.center.y));
      pair(30, '0.0');
      pair(40, _fmt(e.radius));
    case DxfArc e:
      pair(0, 'ARC');
      pair(8, '0');
      pair(10, _fmt(e.center.x));
      pair(20, _fmt(e.center.y));
      pair(30, '0.0');
      pair(40, _fmt(e.radius));
      pair(50, _fmt(e.startAngleDeg));
      pair(51, _fmt(e.endAngleDeg));
    case DxfPolyline e:
      pair(0, 'LWPOLYLINE');
      pair(8, '0');
      pair(90, e.vertices.length);
      pair(70, e.closed ? 1 : 0);
      for (final v in e.vertices) {
        pair(10, _fmt(v.point.x));
        pair(20, _fmt(v.point.y));
        if (v.bulge != 0) {
          pair(42, _fmt(v.bulge));
        }
      }
  }
}
