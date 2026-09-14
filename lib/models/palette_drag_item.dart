import 'hole_preset.dart';

/// What's being dragged from the palette onto the canvas: either a
/// (controller/power-supply) template to place, or a hole preset to stamp.
sealed class PaletteDragItem {
  const PaletteDragItem();
}

class TemplateDragItem extends PaletteDragItem {
  final String templateId;
  const TemplateDragItem(this.templateId);
}

class HolePresetDragItem extends PaletteDragItem {
  final HolePreset preset;
  const HolePresetDragItem(this.preset);
}
