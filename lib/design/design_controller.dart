import 'package:flutter/foundation.dart';

import '../geometry/transform.dart';
import '../models/box_project.dart';
import '../models/hole.dart';
import '../models/hole_preset.dart';
import '../models/placed_template.dart';
import '../models/vec2.dart';
import '../services/template_library.dart';

/// Owns the [BoxProject] being edited and all mutation/selection state for
/// the canvas and property panel.
class DesignController extends ChangeNotifier {
  final TemplateLibrary library;

  DesignController(this.library) {
    library.addListener(notifyListeners);
  }

  BoxProject project = BoxProject();
  String? selectedId;
  int _nextId = 1;

  String _newId(String prefix) => '$prefix-${_nextId++}';

  /// Applies [templateId] (a box-category template) as the enclosure
  /// outline, normalizing its geometry so the bounding box's min corner
  /// sits at (0, 0) — the coordinate frame everything else is placed in.
  void applyBoxTemplate(String templateId) {
    final template = library.byId(templateId);
    if (template == null) return;
    final box = template.boundingBox;
    final normalized = placeEntities(template.entities, delta: Vec2(-box.minX, -box.minY));
    project = project.copyWith(boxTemplateId: templateId, boxOutline: normalized);
    notifyListeners();
  }

  void newProject() {
    final defaultBox = library.defaultBoxTemplate;
    project = BoxProject(
      boxTemplateId: defaultBox?.id,
      boxOutline: defaultBox == null
          ? null
          : placeEntities(defaultBox.entities, delta: Vec2(-defaultBox.boundingBox.minX, -defaultBox.boundingBox.minY)),
    );
    selectedId = null;
    notifyListeners();
  }

  void loadProject(BoxProject loaded) {
    project = loaded;
    selectedId = null;
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void addPlacedTemplate(String templateId, Vec2 position) {
    final placed = PlacedTemplate(
      id: _newId('placed'),
      templateId: templateId,
      position: position,
    );
    project = project.copyWith(placedTemplates: [...project.placedTemplates, placed]);
    selectedId = placed.id;
    notifyListeners();
  }

  void movePlacedTemplate(String id, Vec2 newPosition) {
    project = project.copyWith(
      placedTemplates: [
        for (final p in project.placedTemplates)
          if (p.id == id) p.copyWith(position: newPosition) else p,
      ],
    );
    notifyListeners();
  }

  void rotatePlacedTemplate(String id, double rotationDeg) {
    project = project.copyWith(
      placedTemplates: [
        for (final p in project.placedTemplates)
          if (p.id == id) p.copyWith(rotationDeg: rotationDeg) else p,
      ],
    );
    notifyListeners();
  }

  void addHoleFromPreset(HolePreset preset, Vec2 position) {
    final hole = Hole(
      id: _newId('hole'),
      type: preset.type,
      position: position,
      diameter: preset.diameter,
      slotLength: preset.slotLength,
      slotWidth: preset.slotWidth,
    );
    project = project.copyWith(holes: [...project.holes, hole]);
    selectedId = hole.id;
    notifyListeners();
  }

  void updateHole(String id, Hole Function(Hole) update) {
    project = project.copyWith(
      holes: [
        for (final h in project.holes)
          if (h.id == id) update(h) else h,
      ],
    );
    notifyListeners();
  }

  void deleteSelected() {
    if (selectedId == null) return;
    project = project.copyWith(
      placedTemplates: project.placedTemplates.where((p) => p.id != selectedId).toList(),
      holes: project.holes.where((h) => h.id != selectedId).toList(),
    );
    selectedId = null;
    notifyListeners();
  }

  PlacedTemplate? get selectedTemplate {
    final id = selectedId;
    if (id == null) return null;
    for (final p in project.placedTemplates) {
      if (p.id == id) return p;
    }
    return null;
  }

  Hole? get selectedHole {
    final id = selectedId;
    if (id == null) return null;
    for (final h in project.holes) {
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  void dispose() {
    library.removeListener(notifyListeners);
    super.dispose();
  }
}
