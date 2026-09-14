import 'package:flutter/material.dart';

import 'design/design_controller.dart';
import 'design/box_canvas.dart';
import 'services/template_library.dart';
import 'widgets/left_palette.dart';
import 'widgets/right_property_panel.dart';
import 'widgets/top_toolbar.dart';

void main() {
  runApp(const BoxDesignApp());
}

class BoxDesignApp extends StatelessWidget {
  const BoxDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Box Design',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey)),
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
  late final DesignController _controller = DesignController(_library);
  late final Future<void> _initialLoad = _library.loadBuiltIns().then((_) {
    final defaultBox = _library.defaultBoxTemplate;
    if (defaultBox != null) _controller.applyBoxTemplate(defaultBox.id);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initialLoad,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                TopToolbar(controller: _controller),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 240,
                        child: LeftPalette(library: _library, controller: _controller),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ColoredBox(
                          color: Colors.grey.shade200,
                          child: BoxCanvas(controller: _controller),
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
            );
          },
        ),
      ),
    );
  }
}
