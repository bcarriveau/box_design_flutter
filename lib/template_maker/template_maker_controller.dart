import 'package:flutter/foundation.dart';

import '../models/controller_template.dart';
import '../models/dxf_entity.dart';
import '../models/vec2.dart';

/// A single round mounting hole in the template being built: diameter plus
/// a center position in the template's own local coordinate space (min
/// corner of the outline sits at (0, 0), matching every other template).
class TemplateMakerHole {
  final String id;
  double x;
  double y;
  double diameter;

  TemplateMakerHole({required this.id, required this.x, required this.y, required this.diameter});
}

/// Backs the template maker screen: an outline rectangle (width/height) plus
/// a flat list of round holes, convertible to/from the same
/// [ControllerTemplate] JSON format the rest of the app reads and writes —
/// so a template built here drops straight into `assets/templates/` or an
/// imported/remote template library with no separate format to maintain.
class TemplateMakerController extends ChangeNotifier {
  String id = 'new_template';
  String name = 'New Template';
  TemplateCategory category = TemplateCategory.box;
  double outlineWidth = 100;
  double outlineHeight = 100;
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

  void addHole() {
    holes.add(TemplateMakerHole(
      id: 'hole${_nextHoleSeq++}',
      x: outlineWidth / 2,
      y: outlineHeight / 2,
      diameter: 4,
    ));
    notifyListeners();
  }

  void removeHole(String holeId) {
    holes.removeWhere((h) => h.id == holeId);
    notifyListeners();
  }

  void updateHole(String holeId, {double? x, double? y, double? diameter}) {
    for (final h in holes) {
      if (h.id != holeId) continue;
      if (x != null) h.x = x;
      if (y != null) h.y = y;
      if (diameter != null && diameter > 0) h.diameter = diameter;
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
    holes.clear();
    _nextHoleSeq = 1;
    notifyListeners();
  }

  /// Builds the template's geometry: a closed rectangular outline plus one
  /// [DxfCircle] per hole, exactly the shape [ControllerTemplate.toJson]
  /// (and the rest of the app, e.g. mesh export's own-hole detection) expect.
  ControllerTemplate toTemplate() {
    final outline = DxfPolyline(
      [
        const PolyVertex(Vec2(0, 0)),
        PolyVertex(Vec2(outlineWidth, 0)),
        PolyVertex(Vec2(outlineWidth, outlineHeight)),
        PolyVertex(Vec2(0, outlineHeight)),
      ],
      closed: true,
    );
    final entities = <DxfEntity>[
      outline,
      for (final h in holes) DxfCircle(Vec2(h.x, h.y), h.diameter / 2),
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
  /// app picks out a template's own outline vs. its baked-in holes), and
  /// every [DxfCircle] elsewhere becomes an editable hole. Any other entity
  /// shape (arcs, non-rectangular outlines, lines) is dropped silently —
  /// this tool only ever produces plain rectangles with round holes, so
  /// round-tripping a template it didn't create is best-effort.
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
    if (outlineEntity != null) {
      final b = outlineEntity.boundingBox;
      outlineWidth = b.width;
      outlineHeight = b.height;
    }

    holes.clear();
    _nextHoleSeq = 1;
    for (final e in template.entities) {
      if (identical(e, outlineEntity)) continue;
      if (e is! DxfCircle) continue;
      holes.add(TemplateMakerHole(
        id: 'hole${_nextHoleSeq++}',
        x: e.center.x,
        y: e.center.y,
        diameter: e.radius * 2,
      ));
    }
    notifyListeners();
  }
}
