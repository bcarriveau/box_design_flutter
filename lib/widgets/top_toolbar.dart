import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design_controller.dart';
import '../services/dxf_export.dart';
import '../services/file_io.dart';
import '../services/pdf_export.dart';
import '../services/project_io.dart';
import '../services/stl_export.dart';
import '../services/threemf_export.dart';
import '../template_maker/template_maker_screen.dart';

class TopToolbar extends StatefulWidget {
  final DesignController controller;

  const TopToolbar({super.key, required this.controller});

  @override
  State<TopToolbar> createState() => _TopToolbarState();
}

class _TopToolbarState extends State<TopToolbar> {
  final _thicknessController = TextEditingController(text: '5');

  DesignController get controller => widget.controller;

  double get _thicknessMm => double.tryParse(_thicknessController.text) ?? 5.0;

  @override
  void dispose() {
    _thicknessController.dispose();
    super.dispose();
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _measureToggle(BuildContext context) {
    final active = controller.measureModeEnabled;
    final start = controller.measureStart;
    final end = controller.measureEnd;
    String? label;
    if (start != null && end != null) {
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      label = 'ΔX ${dx.toStringAsFixed(2)}  ΔY ${dy.toStringAsFixed(2)}  ${distance.toStringAsFixed(2)} mm';
    } else if (start != null) {
      label = 'Click a second point…';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        active
            ? FilledButton.icon(
                onPressed: () => controller.toggleMeasureMode(),
                icon: const Icon(Icons.straighten, size: 18),
                label: const Text('Measuring'),
              )
            : OutlinedButton.icon(
                onPressed: () => controller.toggleMeasureMode(),
                icon: const Icon(Icons.straighten, size: 18),
                label: const Text('Measure'),
              ),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final box = controller.library.byId(controller.project.boxTemplateId ?? '');
        return Material(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(onPressed: () => controller.newProject(), child: const Text('New')),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateMakerScreen(library: controller.library))),
                  child: const Text('Template Maker'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final project = await openProject();
                    if (project != null) controller.loadProject(project);
                  },
                  child: const Text('Open'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final result = await saveProject(controller.project);
                    if (context.mounted) _snack(context, result != null ? 'Project saved' : 'Save cancelled');
                  },
                  child: const Text('Save'),
                ),
                const VerticalDivider(width: 1),
                Text(
                  box == null
                      ? 'No box selected'
                      : '${box.name} — ${controller.project.boxWidth.toStringAsFixed(0)}×${controller.project.boxHeight.toStringAsFixed(0)}mm',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const VerticalDivider(width: 1),
                _measureToggle(context),
                const VerticalDivider(width: 1),
                FilledButton(
                  onPressed: () async {
                    final bytes = exportProjectAsDxfBytes(controller.project, controller.library);
                    final result = await saveBytes('${controller.project.name}.dxf', bytes, dialogTitle: 'Export DXF', mimeType: 'application/dxf');
                    if (context.mounted) _snack(context, result != null ? 'DXF exported' : 'Export cancelled');
                  },
                  child: const Text('Export DXF'),
                ),
                FilledButton(
                  onPressed: () async {
                    final bytes = await exportProjectAsPdfBytes(controller.project, controller.library);
                    final result = await saveBytes('${controller.project.name}.pdf', bytes, dialogTitle: 'Export PDF', mimeType: 'application/pdf');
                    if (context.mounted) _snack(context, result != null ? 'PDF exported' : 'Export cancelled');
                  },
                  child: const Text('Export PDF'),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _thicknessController,
                    decoration: const InputDecoration(labelText: 'Plate mm', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final bytes = exportProjectAsStlBytes(controller.project, controller.library, thicknessMm: _thicknessMm);
                    saveBytes('${controller.project.name}.stl', bytes, dialogTitle: 'Export STL', mimeType: 'model/stl').then((result) {
                      if (context.mounted) _snack(context, result != null ? 'STL exported' : 'Export cancelled');
                    });
                  },
                  child: const Text('Export STL'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final bytes = exportProjectAs3mfBytes(controller.project, controller.library, thicknessMm: _thicknessMm);
                    saveBytes('${controller.project.name}.3mf', bytes, dialogTitle: 'Export 3MF', mimeType: 'model/3mf').then((result) {
                      if (context.mounted) _snack(context, result != null ? '3MF exported' : 'Export cancelled');
                    });
                  },
                  child: const Text('Export 3MF'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
