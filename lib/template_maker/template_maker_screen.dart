import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dxf/dxf_parser.dart';
import '../models/controller_template.dart';
import '../models/vec2.dart';
import '../services/file_io.dart';
import '../services/simple_math.dart';
import '../services/template_library.dart';
import 'template_maker_controller.dart';
import 'template_outline_painter.dart';

const double _outlinePreviewMargin = 32.0;
const double _holeDragHitPx = 14.0;

/// A standalone screen for building a [ControllerTemplate] by hand: an
/// outline rectangle sized by width/height fields, plus a list of round
/// holes each given a diameter and X/Y position. Loads and exports the same
/// JSON template format the rest of the app reads, so a file made here can
/// be dropped straight into `assets/templates/` or imported. When opened
/// with a [library] (the running app's live template set), "Add to
/// Library" drops the template straight into it with no file round-trip.
class TemplateMakerScreen extends StatefulWidget {
  final TemplateLibrary? library;

  const TemplateMakerScreen({super.key, this.library});

  @override
  State<TemplateMakerScreen> createState() => _TemplateMakerScreenState();
}

class _TemplateMakerScreenState extends State<TemplateMakerScreen> {
  final _controller = TemplateMakerController();
  String? _draggingHoleId;

  late final _idController = TextEditingController(text: _controller.id);
  late final _nameController = TextEditingController(text: _controller.name);
  late final _widthController = TextEditingController(text: _fmt(_controller.outlineWidth));
  late final _heightController = TextEditingController(text: _fmt(_controller.outlineHeight));
  late final _cornerSizeController = TextEditingController(text: _fmt(_controller.cornerSize));
  final _widthFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _cornerSizeFocus = FocusNode();

  final Map<String, TextEditingController> _holeX = {};
  final Map<String, TextEditingController> _holeY = {};
  final Map<String, TextEditingController> _holeD = {};
  final Map<String, TextEditingController> _holeLen = {};
  final Map<String, TextEditingController> _holeWidth = {};
  final Map<String, TextEditingController> _holeRotation = {};
  final Map<String, FocusNode> _holeXFocus = {};
  final Map<String, FocusNode> _holeYFocus = {};
  final Map<String, FocusNode> _holeDFocus = {};
  final Map<String, FocusNode> _holeLenFocus = {};
  final Map<String, FocusNode> _holeWidthFocus = {};
  final Map<String, FocusNode> _holeRotationFocus = {};

  /// Re-parses [controller]'s current text as a (possibly math-expression)
  /// number and, if valid, applies it via [onCommit] and rewrites the field
  /// to show the plain computed result -- so typing "55-23" and pressing
  /// Enter or clicking away leaves "32.0" in the field instead of the raw
  /// expression. Invalid/incomplete text is left alone (the model already
  /// holds whatever the last valid keystroke committed via onChanged).
  void _commitMathField(TextEditingController controller, void Function(double value) onCommit) {
    final value = tryEvalMath(controller.text);
    if (value == null) return;
    setState(() {
      onCommit(value);
      controller.text = _fmt(value);
    });
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  String _slugify(String name) {
    final slug = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '').toLowerCase();
    return slug.isEmpty ? 'template' : slug;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _cornerSizeController.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    _cornerSizeFocus.dispose();
    for (final c in [
      ..._holeX.values,
      ..._holeY.values,
      ..._holeD.values,
      ..._holeLen.values,
      ..._holeWidth.values,
      ..._holeRotation.values,
    ]) {
      c.dispose();
    }
    for (final f in [
      ..._holeXFocus.values,
      ..._holeYFocus.values,
      ..._holeDFocus.values,
      ..._holeLenFocus.values,
      ..._holeWidthFocus.values,
      ..._holeRotationFocus.values,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncHoleControllers() {
    final liveIds = _controller.holes.map((h) => h.id).toSet();
    for (final map in [_holeX, _holeY, _holeD, _holeLen, _holeWidth, _holeRotation]) {
      map.removeWhere((id, c) {
        final stale = !liveIds.contains(id);
        if (stale) c.dispose();
        return stale;
      });
    }
    for (final map in [_holeXFocus, _holeYFocus, _holeDFocus, _holeLenFocus, _holeWidthFocus, _holeRotationFocus]) {
      map.removeWhere((id, f) {
        final stale = !liveIds.contains(id);
        if (stale) f.dispose();
        return stale;
      });
    }
    for (final h in _controller.holes) {
      _holeX.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.x)));
      _holeY.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.y)));
      _holeD.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.diameter)));
      _holeLen.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.slotLength)));
      _holeWidth.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.slotWidth)));
      _holeRotation.putIfAbsent(h.id, () => TextEditingController(text: _fmt(h.rotationDeg)));
      _holeXFocus.putIfAbsent(h.id, () => FocusNode());
      _holeYFocus.putIfAbsent(h.id, () => FocusNode());
      _holeDFocus.putIfAbsent(h.id, () => FocusNode());
      _holeLenFocus.putIfAbsent(h.id, () => FocusNode());
      _holeWidthFocus.putIfAbsent(h.id, () => FocusNode());
      _holeRotationFocus.putIfAbsent(h.id, () => FocusNode());
    }
  }

  void _refreshTopFields() {
    _idController.text = _controller.id;
    _nameController.text = _controller.name;
    _widthController.text = _fmt(_controller.outlineWidth);
    _heightController.text = _fmt(_controller.outlineHeight);
    _cornerSizeController.text = _fmt(_controller.cornerSize);
    for (final h in _controller.holes) {
      _holeX[h.id]?.text = _fmt(h.x);
      _holeY[h.id]?.text = _fmt(h.y);
      _holeD[h.id]?.text = _fmt(h.diameter);
      _holeLen[h.id]?.text = _fmt(h.slotLength);
      _holeWidth[h.id]?.text = _fmt(h.slotWidth);
      _holeRotation[h.id]?.text = _fmt(h.rotationDeg);
    }
  }

  /// Mirrors [TemplateOutlinePainter]'s scale-to-fit transform so pointer
  /// positions in the preview can be mapped back to template mm-space.
  double _previewScale(Size size) {
    final availableW = size.width - _outlinePreviewMargin * 2;
    final availableH = size.height - _outlinePreviewMargin * 2;
    if (availableW <= 0 || availableH <= 0) return 1;
    return math.min(availableW / _controller.outlineWidth, availableH / _controller.outlineHeight);
  }

  Offset _previewOrigin(Size size, double scale) {
    return Offset(
      (size.width - _controller.outlineWidth * scale) / 2,
      (size.height - _controller.outlineHeight * scale) / 2,
    );
  }

  Vec2 _previewPxToMm(Offset localPx, Size size) {
    final scale = _previewScale(size);
    final origin = _previewOrigin(size, scale);
    return Vec2(
      (localPx.dx - origin.dx) / scale,
      _controller.outlineHeight - (localPx.dy - origin.dy) / scale,
    );
  }

  TemplateMakerHole? _holeNear(Vec2 mm, double scale) {
    final hitToleranceMm = _holeDragHitPx / scale;
    TemplateMakerHole? closest;
    var closestDist = double.infinity;
    for (final h in _controller.holes) {
      final dx = h.x - mm.x;
      final dy = h.y - mm.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      final radiusMm = h.shape == TemplateMakerHoleShape.slot
          ? math.max(h.slotLength, h.slotWidth) / 2
          : h.diameter / 2;
      if (dist <= math.max(radiusMm, hitToleranceMm) && dist < closestDist) {
        closestDist = dist;
        closest = h;
      }
    }
    return closest;
  }

  void _onPreviewPanStart(DragStartDetails details, Size size) {
    final scale = _previewScale(size);
    final mm = _previewPxToMm(details.localPosition, size);
    _draggingHoleId = _holeNear(mm, scale)?.id;
  }

  void _onPreviewPanUpdate(DragUpdateDetails details, Size size) {
    final draggingId = _draggingHoleId;
    if (draggingId == null) return;
    final mm = _previewPxToMm(details.localPosition, size);
    setState(() {
      _controller.updateHole(draggingId, x: mm.x, y: mm.y);
      _holeX[draggingId]?.text = _fmt(mm.x);
      _holeY[draggingId]?.text = _fmt(mm.y);
    });
  }

  void _onPreviewPanEnd(DragEndDetails details) {
    _draggingHoleId = null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadJson() async {
    final picked = await pickFile(allowedExtensions: ['json'], dialogTitle: 'Load Template JSON');
    if (picked == null) return;
    try {
      final json = jsonDecode(utf8.decode(picked.bytes)) as Map<String, dynamic>;
      final template = ControllerTemplate.fromJson(json, source: TemplateSource.imported);
      setState(() {
        _controller.loadFromTemplate(template);
        _syncHoleControllers();
        _refreshTopFields();
      });
      _snack('Loaded ${template.name}');
    } catch (e) {
      _snack('Failed to load: $e');
    }
  }

  Future<void> _loadDxf() async {
    final picked = await pickFile(allowedExtensions: ['dxf'], dialogTitle: 'Load Template DXF');
    if (picked == null) return;
    try {
      final entities = parseDxf(utf8.decode(picked.bytes));
      final name = picked.name.replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '');
      final template = ControllerTemplate(
        id: _slugify(name),
        name: name,
        entities: entities,
        source: TemplateSource.imported,
        category: _controller.category,
      );
      setState(() {
        _controller.loadFromTemplate(template);
        _syncHoleControllers();
        _refreshTopFields();
      });
      _snack('Loaded ${template.name}');
    } catch (e) {
      _snack('Failed to load: $e');
    }
  }

  Future<void> _exportJson() async {
    final template = _controller.toTemplate();
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(template.toJson()));
    final result = await saveBytes('${template.id}.json', bytes, dialogTitle: 'Export Template JSON', mimeType: 'application/json');
    _snack(result != null ? 'Template exported' : 'Export cancelled');
  }

  void _addToLibrary() {
    final library = widget.library;
    if (library == null) return;
    final template = _controller.toTemplate();
    library.importJson(jsonEncode(template.toJson()));
    _snack('Added "${template.name}" to the library');
  }

  void _newTemplate() {
    setState(() {
      _controller.newTemplate();
      _syncHoleControllers();
      _refreshTopFields();
    });
  }

  void _addHole() {
    setState(() {
      _controller.addHole();
      _syncHoleControllers();
      _refreshTopFields();
    });
  }

  void _addSlot() {
    setState(() {
      _controller.addSlot();
      _syncHoleControllers();
      _refreshTopFields();
    });
  }

  void _removeHole(String id) {
    setState(() => _controller.removeHole(id));
  }

  Future<void> _showQuickHoleDialog() async {
    final hCtrl = TextEditingController();
    final vCtrl = TextEditingController();
    final dCtrl = TextEditingController(text: '4');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Quick 4-Hole Pattern'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Places 4 round holes centered on the outline\'s centerline.'),
                const SizedBox(height: 12),
                TextField(
                  controller: hCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Horizontal spacing (mm)', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vCtrl,
                  decoration: const InputDecoration(labelText: 'Vertical spacing (mm)', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dCtrl,
                  decoration: const InputDecoration(labelText: 'Hole diameter (mm)', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Add')),
          ],
        ),
      );
      if (confirmed != true) return;

      final h = tryEvalMath(hCtrl.text);
      final v = tryEvalMath(vCtrl.text);
      final d = tryEvalMath(dCtrl.text);
      if (h == null || v == null || h <= 0 || v <= 0) {
        _snack('Enter a positive horizontal and vertical spacing.');
        return;
      }
      setState(() {
        _controller.addQuickHolePattern(
          horizontalSpacing: h,
          verticalSpacing: v,
          diameter: (d != null && d > 0) ? d : 4,
        );
        _syncHoleControllers();
        _refreshTopFields();
      });
    } finally {
      hCtrl.dispose();
      vCtrl.dispose();
      dCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncHoleControllers();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Maker'),
        actions: [
          TextButton.icon(onPressed: _newTemplate, icon: const Icon(Icons.add), label: const Text('New')),
          TextButton.icon(onPressed: _loadJson, icon: const Icon(Icons.folder_open), label: const Text('Load JSON')),
          TextButton.icon(onPressed: _loadDxf, icon: const Icon(Icons.folder_open), label: const Text('Load DXF')),
          TextButton.icon(onPressed: _exportJson, icon: const Icon(Icons.save_alt), label: const Text('Export JSON')),
          if (widget.library != null)
            TextButton.icon(
              onPressed: _addToLibrary,
              icon: const Icon(Icons.library_add),
              label: const Text('Add to Library'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 340,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Template', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'Id', isDense: true, border: OutlineInputBorder()),
                  onChanged: _controller.setId,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', isDense: true, border: OutlineInputBorder()),
                  onChanged: _controller.setName,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TemplateCategory>(
                  isExpanded: true,
                  initialValue: _controller.category,
                  decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
                  items: [
                    for (final c in TemplateCategory.values) DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _controller.setCategory(v));
                  },
                ),
                const Divider(height: 32),
                Text('Outline', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthController,
                        focusNode: _widthFocus,
                        decoration: const InputDecoration(labelText: 'Width (mm)', isDense: true, border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final parsed = tryEvalMath(v);
                          if (parsed != null) setState(() => _controller.setOutlineWidth(parsed));
                        },
                        onSubmitted: (_) => _commitMathField(_widthController, _controller.setOutlineWidth),
                        onEditingComplete: () => _commitMathField(_widthController, _controller.setOutlineWidth),
                        onTapOutside: (_) {
                          _commitMathField(_widthController, _controller.setOutlineWidth);
                          _widthFocus.unfocus();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        focusNode: _heightFocus,
                        decoration: const InputDecoration(labelText: 'Height (mm)', isDense: true, border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final parsed = tryEvalMath(v);
                          if (parsed != null) setState(() => _controller.setOutlineHeight(parsed));
                        },
                        onSubmitted: (_) => _commitMathField(_heightController, _controller.setOutlineHeight),
                        onEditingComplete: () => _commitMathField(_heightController, _controller.setOutlineHeight),
                        onTapOutside: (_) {
                          _commitMathField(_heightController, _controller.setOutlineHeight);
                          _heightFocus.unfocus();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TemplateMakerCornerStyle>(
                        initialValue: _controller.cornerStyle,
                        decoration: const InputDecoration(labelText: 'Corner style', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: TemplateMakerCornerStyle.fillet, child: Text('Fillet')),
                          DropdownMenuItem(value: TemplateMakerCornerStyle.chamfer, child: Text('Chamfer')),
                          DropdownMenuItem(value: TemplateMakerCornerStyle.cornerCut, child: Text('Corner cut')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _controller.setCornerStyle(v));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cornerSizeController,
                        focusNode: _cornerSizeFocus,
                        decoration: const InputDecoration(labelText: 'Size (mm)', isDense: true, border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final parsed = tryEvalMath(v);
                          if (parsed != null) {
                            setState(() {
                              _controller.setCornerSize(parsed);
                              _refreshTopFields();
                            });
                          }
                        },
                        onSubmitted: (_) => _commitMathField(_cornerSizeController, (v) {
                          _controller.setCornerSize(v);
                          _refreshTopFields();
                        }),
                        onEditingComplete: () => _commitMathField(_cornerSizeController, (v) {
                          _controller.setCornerSize(v);
                          _refreshTopFields();
                        }),
                        onTapOutside: (_) {
                          _commitMathField(_cornerSizeController, (v) {
                            _controller.setCornerSize(v);
                            _refreshTopFields();
                          });
                          _cornerSizeFocus.unfocus();
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Holes', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        IconButton(onPressed: _addHole, icon: const Icon(Icons.add_circle_outline), tooltip: 'Add round hole'),
                        IconButton(onPressed: _addSlot, icon: const Icon(Icons.crop_7_5), tooltip: 'Add slot'),
                        IconButton(onPressed: _showQuickHoleDialog, icon: const Icon(Icons.grid_4x4), tooltip: 'Quick 4-hole pattern'),
                      ],
                    ),
                  ],
                ),
                for (final hole in _controller.holes) _holeRow(hole.id),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ColoredBox(
              color: Colors.grey.shade200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _onPreviewPanStart(details, size),
                      onPanUpdate: (details) => _onPreviewPanUpdate(details, size),
                      onPanEnd: _onPreviewPanEnd,
                      child: CustomPaint(
                        painter: TemplateOutlinePainter(
                          outlineWidth: _controller.outlineWidth,
                          outlineHeight: _controller.outlineHeight,
                          cornerStyle: _controller.cornerStyle,
                          cornerSize: _controller.cornerSize,
                          holes: [
                            for (final h in _controller.holes)
                              (
                                shape: h.shape,
                                center: Vec2(h.x, h.y),
                                diameter: h.diameter,
                                slotLength: h.slotLength,
                                slotWidth: h.slotWidth,
                                rotationDeg: h.rotationDeg,
                              ),
                          ],
                        ),
                        size: size,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _holeRow(String holeId) {
    final hole = _controller.holes.firstWhere((h) => h.id == holeId);
    final isSlot = hole.shape == TemplateMakerHoleShape.slot;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isSlot ? 'Slot' : 'Round hole', style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              IconButton(
                onPressed: () => _removeHole(holeId),
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Remove ${isSlot ? 'slot' : 'hole'}',
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _holeX[holeId],
                  focusNode: _holeXFocus[holeId],
                  decoration: const InputDecoration(labelText: 'X', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = tryEvalMath(v);
                    if (parsed != null) setState(() => _controller.updateHole(holeId, x: parsed));
                  },
                  onSubmitted: (_) => _commitMathField(_holeX[holeId]!, (v) => _controller.updateHole(holeId, x: v)),
                  onEditingComplete: () => _commitMathField(_holeX[holeId]!, (v) => _controller.updateHole(holeId, x: v)),
                  onTapOutside: (_) {
                    _commitMathField(_holeX[holeId]!, (v) => _controller.updateHole(holeId, x: v));
                    _holeXFocus[holeId]?.unfocus();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _holeY[holeId],
                  focusNode: _holeYFocus[holeId],
                  decoration: const InputDecoration(labelText: 'Y', isDense: true, border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = tryEvalMath(v);
                    if (parsed != null) setState(() => _controller.updateHole(holeId, y: parsed));
                  },
                  onSubmitted: (_) => _commitMathField(_holeY[holeId]!, (v) => _controller.updateHole(holeId, y: v)),
                  onEditingComplete: () => _commitMathField(_holeY[holeId]!, (v) => _controller.updateHole(holeId, y: v)),
                  onTapOutside: (_) {
                    _commitMathField(_holeY[holeId]!, (v) => _controller.updateHole(holeId, y: v));
                    _holeYFocus[holeId]?.unfocus();
                  },
                ),
              ),
              const SizedBox(width: 6),
              if (!isSlot)
                Expanded(
                  child: TextField(
                    controller: _holeD[holeId],
                    focusNode: _holeDFocus[holeId],
                    decoration: const InputDecoration(labelText: 'Dia', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final parsed = tryEvalMath(v);
                      if (parsed != null) setState(() => _controller.updateHole(holeId, diameter: parsed));
                    },
                    onSubmitted: (_) => _commitMathField(_holeD[holeId]!, (v) => _controller.updateHole(holeId, diameter: v)),
                    onEditingComplete: () => _commitMathField(_holeD[holeId]!, (v) => _controller.updateHole(holeId, diameter: v)),
                    onTapOutside: (_) {
                      _commitMathField(_holeD[holeId]!, (v) => _controller.updateHole(holeId, diameter: v));
                      _holeDFocus[holeId]?.unfocus();
                    },
                  ),
                ),
            ],
          ),
          if (isSlot) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _holeLen[holeId],
                    focusNode: _holeLenFocus[holeId],
                    decoration: const InputDecoration(labelText: 'Length', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final parsed = tryEvalMath(v);
                      if (parsed != null) setState(() => _controller.updateHole(holeId, slotLength: parsed));
                    },
                    onSubmitted: (_) => _commitMathField(_holeLen[holeId]!, (v) => _controller.updateHole(holeId, slotLength: v)),
                    onEditingComplete: () => _commitMathField(_holeLen[holeId]!, (v) => _controller.updateHole(holeId, slotLength: v)),
                    onTapOutside: (_) {
                      _commitMathField(_holeLen[holeId]!, (v) => _controller.updateHole(holeId, slotLength: v));
                      _holeLenFocus[holeId]?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _holeWidth[holeId],
                    focusNode: _holeWidthFocus[holeId],
                    decoration: const InputDecoration(labelText: 'Width', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final parsed = tryEvalMath(v);
                      if (parsed != null) setState(() => _controller.updateHole(holeId, slotWidth: parsed));
                    },
                    onSubmitted: (_) => _commitMathField(_holeWidth[holeId]!, (v) => _controller.updateHole(holeId, slotWidth: v)),
                    onEditingComplete: () => _commitMathField(_holeWidth[holeId]!, (v) => _controller.updateHole(holeId, slotWidth: v)),
                    onTapOutside: (_) {
                      _commitMathField(_holeWidth[holeId]!, (v) => _controller.updateHole(holeId, slotWidth: v));
                      _holeWidthFocus[holeId]?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _holeRotation[holeId],
                    focusNode: _holeRotationFocus[holeId],
                    decoration: const InputDecoration(labelText: 'Rotation°', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    onChanged: (v) {
                      final parsed = tryEvalMath(v);
                      if (parsed != null) setState(() => _controller.updateHole(holeId, rotationDeg: parsed));
                    },
                    onSubmitted: (_) => _commitMathField(_holeRotation[holeId]!, (v) => _controller.updateHole(holeId, rotationDeg: v)),
                    onEditingComplete: () => _commitMathField(_holeRotation[holeId]!, (v) => _controller.updateHole(holeId, rotationDeg: v)),
                    onTapOutside: (_) {
                      _commitMathField(_holeRotation[holeId]!, (v) => _controller.updateHole(holeId, rotationDeg: v));
                      _holeRotationFocus[holeId]?.unfocus();
                    },
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }
}
