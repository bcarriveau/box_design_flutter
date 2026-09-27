/// A named, pre-filled "additional hardware" entry offered in the Template
/// Maker's Hardware tab, so a common item (the layer spacer, a standard
/// bolt) can be picked from a list instead of typed out by hand each time.
class HardwarePreset {
  final String id;
  final String label;
  final int quantity;
  final String? url;
  final String? assetPath;
  final String? assetFileName;

  const HardwarePreset({
    required this.id,
    required this.label,
    this.quantity = 1,
    this.url,
    this.assetPath,
    this.assetFileName,
  });

  /// The `additionalHardware` list entry this preset produces -- same shape
  /// [ControllerTemplate.additionalHardware] and the properties panel
  /// expect.
  Map<String, dynamic> toHardwareItemJson() => {
        'label': label,
        'quantity': quantity,
        if (url != null) 'url': url,
        if (assetPath != null) 'assetPath': assetPath,
        if (assetFileName != null) 'assetFileName': assetFileName,
      };

  static const builtIns = <HardwarePreset>[
    HardwarePreset(
      id: 'layer_spacer',
      label: 'Layer spacer (3D-printed, STL)',
      quantity: 4,
      assetPath: 'assets/hardware/bolt_spacer.stl',
      assetFileName: 'bolt_spacer.stl',
    ),
    HardwarePreset(
      id: 'bolt_1_4x6',
      label: '1/4 in x 6 in bolt',
      quantity: 4,
      url: 'https://www.lowes.com/pd/Hillman-1-4-in-x-6-in-Zinc-Plated-Coarse-Thread-Carriage-Bolt/1000381949',
    ),
    HardwarePreset(
      id: 'nut_1_4',
      label: '1/4 in hex nut',
      quantity: 4,
    ),
    HardwarePreset(
      id: 'washer_1_4',
      label: '1/4 in flat washer',
      quantity: 4,
    ),
    HardwarePreset(
      id: 'standoff_m3',
      label: 'M3 x 10mm standoff',
      quantity: 4,
    ),
    HardwarePreset(
      id: 'screw_m3x8',
      label: 'M3 x 8mm screw',
      quantity: 4,
    ),
  ];
}
