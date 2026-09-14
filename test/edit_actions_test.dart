import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/design/design_controller.dart';
import 'package:box_design_flutter/models/hole.dart';
import 'package:box_design_flutter/models/placed_template.dart';
import 'package:box_design_flutter/models/vec2.dart';
import 'package:box_design_flutter/services/template_library.dart';

void main() {
  test('deleteSelected removes the selected hole and clears the selection', () {
    final controller = DesignController(TemplateLibrary());
    final hole = Hole(id: 'h1', type: HoleType.screw, position: const Vec2(10, 10));
    controller.project = controller.project.copyWith(holes: [hole]);
    controller.select('h1');

    controller.deleteSelected();

    expect(controller.project.holes, isEmpty);
    expect(controller.selectedId, isNull);
  });

  test('deleteSelected removes the selected placed template and clears the selection', () {
    final controller = DesignController(TemplateLibrary());
    final placed = PlacedTemplate(id: 'p1', templateId: 'anything', position: const Vec2(0, 0));
    controller.project = controller.project.copyWith(placedTemplates: [placed]);
    controller.select('p1');

    controller.deleteSelected();

    expect(controller.project.placedTemplates, isEmpty);
    expect(controller.selectedId, isNull);
  });

  test('copy then paste a hole creates an offset duplicate and selects it', () {
    final controller = DesignController(TemplateLibrary());
    final hole = Hole(id: 'h1', type: HoleType.zipTie, position: const Vec2(20, 30), diameter: 5, slotLength: 15, slotWidth: 4);
    controller.project = controller.project.copyWith(holes: [hole]);
    controller.select('h1');

    controller.copySelected();
    controller.pasteClipboard();

    expect(controller.project.holes, hasLength(2));
    final pasted = controller.project.holes.last;
    expect(pasted.id, isNot('h1'));
    expect(pasted.position, const Vec2(30, 40));
    expect(pasted.type, HoleType.zipTie);
    expect(pasted.diameter, 5);
    expect(pasted.slotLength, 15);
    expect(pasted.slotWidth, 4);
    expect(controller.selectedId, pasted.id);
  });

  test('copy then paste a placed template creates an offset duplicate and selects it', () {
    final controller = DesignController(TemplateLibrary());
    final placed = PlacedTemplate(id: 'p1', templateId: 'my_template', position: const Vec2(5, 5), rotationDeg: 90);
    controller.project = controller.project.copyWith(placedTemplates: [placed]);
    controller.select('p1');

    controller.copySelected();
    controller.pasteClipboard();

    expect(controller.project.placedTemplates, hasLength(2));
    final pasted = controller.project.placedTemplates.last;
    expect(pasted.id, isNot('p1'));
    expect(pasted.templateId, 'my_template');
    expect(pasted.position, const Vec2(15, 15));
    expect(pasted.rotationDeg, 90);
    expect(controller.selectedId, pasted.id);
  });

  test('pasteClipboard is a no-op when nothing has been copied', () {
    final controller = DesignController(TemplateLibrary());

    controller.pasteClipboard();

    expect(controller.project.holes, isEmpty);
    expect(controller.project.placedTemplates, isEmpty);
  });
}
