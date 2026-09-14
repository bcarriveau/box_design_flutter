import 'package:flutter/material.dart';

import '../design/design_controller.dart';
import '../models/hole.dart';
import '../models/vec2.dart';

class RightPropertyPanel extends StatefulWidget {
  final DesignController controller;

  const RightPropertyPanel({super.key, required this.controller});

  @override
  State<RightPropertyPanel> createState() => _RightPropertyPanelState();
}

class _RightPropertyPanelState extends State<RightPropertyPanel> {
  String? _lastSelectedId;
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  final _rotController = TextEditingController();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _xFocus = FocusNode();
  final _yFocus = FocusNode();
  final _diameterFocus = FocusNode();
  final _lengthFocus = FocusNode();
  final _widthFocus = FocusNode();

  DesignController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
    _syncFields(force: true);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    for (final c in [_xController, _yController, _rotController, _diameterController, _lengthController, _widthController]) {
      c.dispose();
    }
    for (final f in [_xFocus, _yFocus, _diameterFocus, _lengthFocus, _widthFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    final selectionChanged = controller.selectedId != _lastSelectedId;
    _lastSelectedId = controller.selectedId;
    // Always keep unfocused fields live (e.g. after a canvas drag) so a
    // later edit to one field never commits a stale value for another.
    // A field mid-edit is left alone so we don't clobber the user's typing.
    _syncFields(force: selectionChanged);
    setState(() {});
  }

  void _syncFields({required bool force}) {
    final placed = controller.selectedTemplate;
    final hole = controller.selectedHole;
    if (placed != null) {
      if (force || !_xFocus.hasFocus) _xController.text = placed.position.x.toStringAsFixed(2);
      if (force || !_yFocus.hasFocus) _yController.text = placed.position.y.toStringAsFixed(2);
      _rotController.text = placed.rotationDeg.toStringAsFixed(0);
    } else if (hole != null) {
      if (force || !_xFocus.hasFocus) _xController.text = hole.position.x.toStringAsFixed(2);
      if (force || !_yFocus.hasFocus) _yController.text = hole.position.y.toStringAsFixed(2);
      _rotController.text = hole.rotationDeg.toStringAsFixed(0);
      if (force || !_diameterFocus.hasFocus) _diameterController.text = hole.diameter.toStringAsFixed(2);
      if (force || !_lengthFocus.hasFocus) _lengthController.text = hole.slotLength.toStringAsFixed(2);
      if (force || !_widthFocus.hasFocus) _widthController.text = hole.slotWidth.toStringAsFixed(2);
    }
  }

  void _applyPosition() {
    final x = double.tryParse(_xController.text);
    final y = double.tryParse(_yController.text);
    if (x == null || y == null) return;
    final placed = controller.selectedTemplate;
    final hole = controller.selectedHole;
    if (placed != null) {
      controller.movePlacedTemplate(placed.id, Vec2(x, y));
    } else if (hole != null) {
      controller.updateHole(hole.id, (h) => h.copyWith(position: Vec2(x, y)));
    }
  }

  void _applyRotation(double degrees) {
    final placed = controller.selectedTemplate;
    final hole = controller.selectedHole;
    if (placed != null) {
      controller.rotatePlacedTemplate(placed.id, degrees);
    } else if (hole != null) {
      controller.updateHole(hole.id, (h) => h.copyWith(rotationDeg: degrees));
    }
    _rotController.text = degrees.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final placed = controller.selectedTemplate;
    final hole = controller.selectedHole;

    if (placed == null && hole == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Select an item to edit its properties.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            placed != null ? (controller.library.byId(placed.templateId)?.name ?? placed.templateId) : (hole!.type == HoleType.screw ? 'Screw Hole' : 'Zip-Tie Slot'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField('X (mm)', _xController, _xFocus, _applyPosition)),
              const SizedBox(width: 8),
              Expanded(child: _numberField('Y (mm)', _yController, _yFocus, _applyPosition)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Rotation'),
          Wrap(
            spacing: 6,
            children: [
              for (final deg in [0.0, 90.0, 180.0, 270.0])
                OutlinedButton(onPressed: () => _applyRotation(deg), child: Text('${deg.toInt()}°')),
            ],
          ),
          if (hole != null && hole.type == HoleType.screw) ...[
            const SizedBox(height: 12),
            _numberField('Diameter (mm)', _diameterController, _diameterFocus, () {
              final d = double.tryParse(_diameterController.text);
              if (d != null) controller.updateHole(hole.id, (h) => h.copyWith(diameter: d));
            }),
          ],
          if (hole != null && hole.type == HoleType.zipTie) ...[
            const SizedBox(height: 12),
            _numberField('Slot length (mm)', _lengthController, _lengthFocus, () {
              final v = double.tryParse(_lengthController.text);
              if (v != null) controller.updateHole(hole.id, (h) => h.copyWith(slotLength: v));
            }),
            const SizedBox(height: 8),
            _numberField('Slot width (mm)', _widthController, _widthFocus, () {
              final v = double.tryParse(_widthController.text);
              if (v != null) controller.updateHole(hole.id, (h) => h.copyWith(slotWidth: v));
            }),
          ],
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: controller.deleteSelected,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade50),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _numberField(String label, TextEditingController fieldController, FocusNode focusNode, VoidCallback onSubmit) {
    return TextField(
      controller: fieldController,
      focusNode: focusNode,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onSubmitted: (_) => onSubmit(),
      onEditingComplete: onSubmit,
      onTapOutside: (_) {
        onSubmit();
        focusNode.unfocus();
      },
    );
  }
}
