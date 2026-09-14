import 'package:flutter/material.dart';

import '../design/design_controller.dart';
import '../services/dxf_export.dart';
import '../services/file_io.dart';
import '../services/pdf_export.dart';
import '../services/project_io.dart';

class TopToolbar extends StatelessWidget {
  final DesignController controller;

  const TopToolbar({super.key, required this.controller});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              ],
            ),
          ),
        );
      },
    );
  }
}
