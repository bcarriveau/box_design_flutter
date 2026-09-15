import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/controller_template.dart';
import '../models/dxf_entity.dart';
import '../models/vec2.dart';

const _bulge90 = 0.4142135623730951; // tan(90deg / 4), quarter-circle bulge

enum TemplateMakerHoleShape { round, slot }

/// A single mounting hole in the template being built: either a round hole
/// (sized by [diameter]) or an elongated slot (sized by [slotLength] /
/// [slotWidth] and oriented by [rotationDeg]), with a center position in
/// the template's own local coordinate space (min corner of the outline
/// sits at (0, 0), matching every other template).
class TemplateMakerHole {
  final String id;
  TemplateMakerHoleShape shape;
  double x;
  double y;
  double diameter;
  double slotLength;
  double slotWidth;
  double rotationDeg;

  TemplateMakerHole({
    required this.id,
    required this.x,
    required this.y,
    this.shape = TemplateMakerHoleShape.round,
    this.diameter = 4,
    this.slotLength = 12,
    this.slotWidth = 4,
    this.rotationDeg = 0,
  });
}

/// A rectangle outline with a square notch cut from each corner (e.g. for
/// corner clearance around fasteners or an adjoining panel), as a single
/// closed 12-vertex polygon -- no bulge, every edge straight. [cut] is
/// clamped by the caller to at most half the shorter side.
List<PolyVertex> notchedRectVertices(double width, double height, double cut) {
  final c = cut;
  return [
    PolyVertex(Vec2(c, 0)),
    PolyVertex(Vec2(width - c, 0)),
    PolyVertex(Vec2(width - c, c)),
    PolyVertex(Vec2(width, c)),
    PolyVertex(Vec2(width, height - c)),
    PolyVertex(Vec2(width - c, height - c)),
    PolyVertex(Vec2(width - c, height)),
    PolyVertex(Vec2(c, height)),
    PolyVertex(Vec2(c, height - c)),
    PolyVertex(Vec2(0, height - c)),
    PolyVertex(Vec2(0, c)),
    PolyVertex(Vec2(c, c)),
  ];
}

double _dist(Vec2 a, Vec2 b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// Backs the template maker screen: an outline rectangle (width/height,
/// optionally corner-filleted or corner-notched) plus a flat list of round
/// or slot holes, convertible to/from the same [ControllerTemplate] JSON
/// format the rest of the app reads and writes -- so a template built here
/// drops straight into `assets/templates/` or an imported/remote template
/// library with no separate format to maintain.
class TemplateMakerController extends ChangeNotifier {
  String id = 'new_template';
  String name = 'New Template';
  TemplateCategory category = TemplateCategory.box;
  double outlineWidth = 100;
  double outlineHeight = 100;
  double cornerRadius = 0;
  double cornerCutSize = 0;
  final List<TemplateMakerHole> holes = [];

  int _nextHoleSeq = 1;

  void setId(String value) {
    id = value;
    notifyListeners();
  }

  void setName(String value) {
    name = value;
    notifyListeners();
  }

  void setCategory(TemplateCategory value) {
    category = value;
    notifyListeners();
  }

  void setOutlineWidth(double value) {
    if (value <= 0) return;
    outlineWidth = value;
    notifyListeners();
  }

  void setOutlineHeight(double value) {
    if (value <= 0) return;
    outlineHeight = value;
    notifyListeners();
  }

  /// Corner fillet radius in mm, 0 for sharp corners. Mutually exclusive
  /// with [cornerCutSize] (setting one clears the other). Clamped to the
  /// outline's own half-width/height when applied so it can never invert
  /// the rectangle.
  void setCornerRadius(double value) {
    if (value < 0) return;
    cornerRadius = value;
    if (value > 0) cornerCutSize = 0;
    notifyListeners();
  }

  /// Square notch size in mm cut from each corner, 0 for plain sharp
  /// corners. Mutually exclusive with [cornerRadius].
  void setCornerCutSize(double value) {
    if (value < 0) return;
    cornerCutSize = value;
    if (value > 0) cornerRadius = 0;
    notifyListeners();
  }

  void addHole() {
    holes.add(TemplateMakerHole(
      id: 'hole${_nextHoleSeq++}',
      x: outlineWidth / 2,
      y: outlineHeight / 2,
      diameter: 4,
    ));
    notifyListeners();
  }

  void addSlot() {
    holes.add(TemplateMakerHole(
      id: 'hole${_nextHoleSeq++}',
      x: outlineWidth / 2,
      y: outlineHeight / 2,
      shape: TemplateMakerHoleShape.slot,
      slotLength: 12,
      slotWidth: 4,
    ));
    notifyListeners();
  }

  void removeHole(String holeId) {
    holes.removeWhere((h) => h.id == holeId);
    notifyListeners();
  }

  void updateHole(
    String holeId, {
    double? x,
    double? y,
    double? diameter,
    double? slotLength,
    double? slotWidth,
    double? rotationDeg,
  }) {
    for (final h in holes) {
      if (h.id != holeId) continue;
      if (x != null) h.x = x;
      if (y != null) h.y = y;
      if (diameter != null && diameter > 0) h.diameter = diameter;
      if (slotLength != null && slotLength > 0) h.slotLength = slotLength;
      if (slotWidth != null && slotWidth > 0) h.slotWidth = slotWidth;
      if (rotationDeg != null) h.rotationDeg = rotationDeg;
      break;
    }
    notifyListeners();
  }

  void newTemplate() {
    id = 'new_template';
    name = 'New Template';
    category = TemplateCategory.box;
    outlineWidth = 100;
    outlineHeight = 100;
    cornerRadius = 0;
    cornerCutSize = 0;
    holes.clear();
    _nextHoleSeq = 1;
    notifyListeners();
  }

  /// Builds the template's geometry: a closed rectangular outline --
  /// optionally corner-filleted or corner-notched -- plus one [DxfCircle]
  /// per round hole and one closed stadium [DxfPolyline] per slot hole,
  /// exactly the shape [ControllerTemplate.toJson] (and the rest of the
  /// app, e.g. mesh export's own-hole detection) expect.
  ControllerTemplate toTemplate() {
    final r = cornerRadius <= 0 ? 0.0 : math.min(cornerRadius, math.min(outlineWidth, outlineHeight) / 2);
    final cut = cornerCutSize <= 0 ? 0.0 : math.min(cornerCutSize, math.min(outlineWidth, outlineHeight) / 2);
    final List<PolyVertex> vertices;
    if (cut > 0) {
      vertices = notchedRectVertices(outlineWidth, outlineHeight, cut);
    } else if (r > 0) {
      vertices = [
        PolyVertex(Vec2(r, 0)),
        PolyVertex(Vec2(outlineWidth - r, 0), bulge: _bulge90),
        PolyVertex(Vec2(outlineWidth, r)),
        PolyVertex(Vec2(outlineWidth, outlineHeight - r), bulge: _bulge90),
        PolyVertex(Vec2(outlineWidth - r, outlineHeight)),
        PolyVertex(Vec2(r, outlineHeight), bulge: _bulge90),
        PolyVertex(Vec2(0, outlineHeight - r)),
        PolyVertex(Vec2(0, r), bulge: _bulge90),
      ];
    } else {
      vertices = [
        const PolyVertex(Vec2(0, 0)),
        PolyVertex(Vec2(outlineWidth, 0)),
        PolyVertex(Vec2(outlineWidth, outlineHeight)),
        PolyVertex(Vec2(0, outlineHeight)),
      ];
    }
    final entities = <DxfEntity>[
      DxfPolyline(vertices, closed: true),
      for (final h in holes)
        if (h.shape == TemplateMakerHoleShape.round)
          DxfCircle(Vec2(h.x, h.y), h.diameter / 2)
        else
          DxfPolyline(stadiumVertices(h.slotLength, h.slotWidth), closed: true)
              .transformed(delta: Vec2(h.x, h.y), rotationDeg: h.rotationDeg),
    ];
    return ControllerTemplate(
      id: id,
      name: name,
      entities: entities,
      source: TemplateSource.imported,
      category: category,
    );
  }

  /// Loads an existing template back into editable fields: the
  /// largest-area entity becomes the outline (matching how the rest of the
  /// app picks out a template's own outline vs. its baked-in holes); every
  /// [DxfCircle] elsewhere becomes an editable round hole, and every
  /// 4-vertex closed polyline matching this tool's own stadium bulge
  /// pattern (bulge 1.0 on vertices 0 and 2, matching [stadiumVertices])
  /// becomes an editable slot. Any other entity shape (arcs, non-rectangular
  /// outlines, lines, a slot built some other way) is dropped silently --
  /// this tool only ever produces the shapes above, so round-tripping a
  /// template it didn't create is best-effort.
  void loadFromTemplate(ControllerTemplate template) {
    id = template.id;
    name = template.name;
    category = template.category;

    DxfEntity? outlineEntity;
    var bestArea = 0.0;
    for (final e in template.entities) {
      final b = e.boundingBox;
      final area = b.width * b.height;
      if (area > bestArea) {
        bestArea = area;
        outlineEntity = e;
      }
    }
    cornerRadius = 0;
    cornerCutSize = 0;
    if (outlineEntity != null) {
      final b = outlineEntity.boundingBox;
      outlineWidth = b.width;
      outlineHeight = b.height;
      // This tool's own filleted/notched outlines are always an 8- or
      // 12-vertex polyline in a fixed shape (see toTemplate) -- read the
      // radius/cut size back off that shape. Any other rounded- or
      // notched-corner encoding isn't recognized and comes back in as
      // sharp corners instead.
      if (outlineEntity is DxfPolyline) {
        final verts = outlineEntity.vertices;
        if (verts.length == 8 && verts.any((v) => v.bulge != 0)) {
          cornerRadius = verts.first.point.x.abs();
        } else if (verts.length == 12 && verts.every((v) => v.bulge == 0)) {
          cornerCutSize = verts.first.point.x.abs();
        }
      }
    }

    holes.clear();
    _nextHoleSeq = 1;
    for (final e in template.entities) {
      if (identical(e, outlineEntity)) continue;
      if (e is DxfCircle) {
        holes.add(TemplateMakerHole(
          id: 'hole${_nextHoleSeq++}',
          x: e.center.x,
          y: e.center.y,
          diameter: e.radius * 2,
        ));
        continue;
      }
      if (e is DxfPolyline && e.closed && e.vertices.length == 4) {
        final bulges = e.vertices.map((v) => v.bulge).toList();
        final isStadium = (bulges[0] - 1.0).abs() < 1e-6 &&
            bulges[1] == 0 &&
            (bulges[2] - 1.0).abs() < 1e-6 &&
            bulges[3] == 0;
        if (!isStadium) continue;
        final v0 = e.vertices[0].point;
        final v1 = e.vertices[1].point;
        final v2 = e.vertices[2].point;
        final v3 = e.vertices[3].point;
        final center = Vec2((v0.x + v1.x + v2.x + v3.x) / 4, (v0.y + v1.y + v2.y + v3.y) / 4);
        final width = _dist(v0, v1);
        final straightSpan = _dist(v1, v2);
        final rotationDeg = math.atan2(v1.y - v0.y, v1.x - v0.x) * 180 / math.pi - 90;
        holes.add(TemplateMakerHole(
          id: 'hole${_nextHoleSeq++}',
          x: center.x,
          y: center.y,
          shape: TemplateMakerHoleShape.slot,
          slotLength: straightSpan + width,
          slotWidth: width,
          rotationDeg: rotationDeg,
        ));
      }
    }
    notifyListeners();
  }
}
