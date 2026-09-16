import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/design_controller.dart';
import 'design/box_canvas.dart';
import 'services/hole_preset_library.dart';
import 'services/template_library.dart';
import 'widgets/left_palette.dart';
import 'widgets/right_property_panel.dart';
import 'widgets/top_toolbar.dart';
import 'version.dart';

void main() {
  runApp(const BoxDesignApp());
}

class BoxDesignApp extends StatelessWidget {
  const BoxDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Box Design',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const BoxDesignHomePage(),
    );
  }
}

class BoxDesignHomePage extends StatefulWidget {
  const BoxDesignHomePage({super.key});

  @override
  State<BoxDesignHomePage> createState() => _BoxDesignHomePageState();
}

class _BoxDesignHomePageState extends State<BoxDesignHomePage> {
  final TemplateLibrary _library = TemplateLibrary();
  final HolePresetLibrary _holePresetLibrary = HolePresetLibrary();
  late final DesignController _controller = DesignController(_library);
  final FocusNode _canvasFocusNode = FocusNode();
  late final Future<void> _initialLoad = _library.loadBuiltIns().then((_) {
    final defaultBox = _library.defaultBoxTemplate;
    if (defaultBox != null) _controller.applyBoxTemplate(defaultBox.id);
    // Fire-and-forget: refreshes/extends the bundled set from GitHub in the
    // background once the UI is already up on the bundled templates, so a
    // slow or unreachable network never delays first paint.
    _library.loadRemoteDefaults();
    _holePresetLibrary.loadRemoteDefaults();
  });

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    _holePresetLibrary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: FutureBuilder<void>(
              future: _initialLoad,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Focus(
                  focusNode: _canvasFocusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) => _handleKeyEvent(event),
                  child: Column(
                    children: [
                      TopToolbar(controller: _controller),
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 240,
                              child: LeftPalette(
                                library: _library,
                                holePresetLibrary: _holePresetLibrary,
                                controller: _controller,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: ColoredBox(
                                color: Colors.grey.shade200,
                                child: BoxCanvas(
                                  controller: _controller,
                                  focusNode: _canvasFocusNode,
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: 280,
                              child: RightPropertyPanel(controller: _controller),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 6,
            bottom: 4,
            child: IgnorePointer(
              child: Text(
                'v$appVersion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Delete/Backspace deletes the selected item; Ctrl/Cmd+C and Ctrl/Cmd+V
  /// copy and paste it. A focused text field (e.g. a property panel number
  /// field) consumes these keys itself for editing/text-clipboard use
  /// before they ever reach here, so this only fires for the canvas.
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _controller.deleteSelected();
      return KeyEventResult.handled;
    }

    final isCtrlOrCmd =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyC) {
      _controller.copySelected();
      return KeyEventResult.handled;
    }
    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyV) {
      _controller.pasteClipboard();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
