import '../models/dxf_entity.dart';
import '../models/vec2.dart';

/// Parses the ENTITIES section of an ASCII DXF file into our internal
/// geometry model. Supports LINE, CIRCLE, ARC and LWPOLYLINE (with bulge);
/// unsupported entity types are skipped.
List<DxfEntity> parseDxf(String content) {
  final tokens = _tokenize(content);

  var start = -1;
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].key == 2 && tokens[i].value == 'ENTITIES') {
      start = i + 1;
      break;
    }
  }
  if (start == -1) return [];

  var end = tokens.length;
  for (var i = start; i < tokens.length; i++) {
    if (tokens[i].key == 0 && tokens[i].value == 'ENDSEC') {
      end = i;
      break;
    }
  }

  final section = tokens.sublist(start, end);
  final entities = <DxfEntity>[];
  var i = 0;
  while (i < section.length) {
    if (section[i].key != 0) {
      i++;
      continue;
    }
    final entityType = section[i].value;
    var j = i + 1;
    while (j < section.length && section[j].key != 0) {
      j++;
    }
    final body = section.sublist(i + 1, j);
    final entity = _buildEntity(entityType, body);
    if (entity != null) entities.add(entity);
    i = j;
  }
  return entities;
}

List<MapEntry<int, String>> _tokenize(String content) {
  final rawLines = content.split(RegExp(r'\r\n|\r|\n'));
  var end = rawLines.length;
  while (end > 0 && rawLines[end - 1].trim().isEmpty) {
    end--;
  }
  final lines = rawLines.sublist(0, end);
  final pairs = <MapEntry<int, String>>[];
  for (var i = 0; i + 1 < lines.length; i += 2) {
    final code = int.tryParse(lines[i].trim());
    if (code == null) continue;
    pairs.add(MapEntry(code, lines[i + 1].trim()));
  }
  return pairs;
}

DxfEntity? _buildEntity(String type, List<MapEntry<int, String>> body) {
  switch (type) {
    case 'LINE':
      return _buildLine(body);
    case 'CIRCLE':
      return _buildCircle(body);
    case 'ARC':
      return _buildArc(body);
    case 'LWPOLYLINE':
      return _buildLwPolyline(body);
    default:
      return null;
  }
}

DxfEntity? _buildLine(List<MapEntry<int, String>> body) {
  double? x1, y1, x2, y2;
  for (final t in body) {
    switch (t.key) {
      case 10:
        x1 = double.tryParse(t.value);
      case 20:
        y1 = double.tryParse(t.value);
      case 11:
        x2 = double.tryParse(t.value);
      case 21:
        y2 = double.tryParse(t.value);
    }
  }
  if (x1 == null || y1 == null || x2 == null || y2 == null) return null;
  return DxfLine(Vec2(x1, y1), Vec2(x2, y2));
}

DxfEntity? _buildCircle(List<MapEntry<int, String>> body) {
  double? x, y, r;
  for (final t in body) {
    switch (t.key) {
      case 10:
        x = double.tryParse(t.value);
      case 20:
        y = double.tryParse(t.value);
      case 40:
        r = double.tryParse(t.value);
    }
  }
  if (x == null || y == null || r == null) return null;
  return DxfCircle(Vec2(x, y), r);
}

DxfEntity? _buildArc(List<MapEntry<int, String>> body) {
  double? x, y, r, startAngle, endAngle;
  for (final t in body) {
    switch (t.key) {
      case 10:
        x = double.tryParse(t.value);
      case 20:
        y = double.tryParse(t.value);
      case 40:
        r = double.tryParse(t.value);
      case 50:
        startAngle = double.tryParse(t.value);
      case 51:
        endAngle = double.tryParse(t.value);
    }
  }
  if (x == null || y == null || r == null || startAngle == null || endAngle == null) {
    return null;
  }
  return DxfArc(Vec2(x, y), r, startAngle, endAngle);
}

DxfEntity? _buildLwPolyline(List<MapEntry<int, String>> body) {
  final vertices = <PolyVertex>[];
  double? curX, curY, curBulge;
  var closed = false;

  void flush() {
    if (curX != null && curY != null) {
      vertices.add(PolyVertex(Vec2(curX!, curY!), bulge: curBulge ?? 0));
    }
    curX = null;
    curY = null;
    curBulge = null;
  }

  for (final t in body) {
    switch (t.key) {
      case 10:
        flush();
        curX = double.tryParse(t.value);
      case 20:
        curY = double.tryParse(t.value);
      case 42:
        curBulge = double.tryParse(t.value);
      case 70:
        closed = ((int.tryParse(t.value) ?? 0) & 1) != 0;
    }
  }
  flush();

  if (vertices.isEmpty) return null;
  return DxfPolyline(vertices, closed: closed);
}
