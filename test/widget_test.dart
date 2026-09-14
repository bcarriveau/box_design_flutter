import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/main.dart';

void main() {
  testWidgets('App loads templates and shows the toolbar', (WidgetTester tester) async {
    await tester.pumpWidget(const BoxDesignApp());
    await tester.pumpAndSettle();

    expect(find.text('Box Template'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Export DXF'), findsOneWidget);
    expect(find.textContaining('CG-1500'), findsOneWidget);

    // The palette's category tree is a scrollable list, and its Sliver
    // virtualizes items outside the viewport + cache extent — with many
    // bundled controller/receiver templates now expanded by default, no
    // single scroll position keeps every section mounted simultaneously.
    // Sweep the full scroll range and confirm each section is mounted at
    // some point along the way.
    final palette = find.byType(ListView).first;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: palette, matching: find.byType(Scrollable)).first,
    );
    final sectionsSeen = <String>{};
    const sections = ['Controllers', 'Receivers', 'Power Supplies', 'Generic Holes'];
    final maxExtent = scrollable.position.maxScrollExtent;
    for (var offset = 0.0; offset <= maxExtent; offset += 150) {
      scrollable.position.jumpTo(offset);
      await tester.pumpAndSettle();
      for (final section in sections) {
        if (find.text(section).evaluate().isNotEmpty) sectionsSeen.add(section);
      }
    }
    scrollable.position.jumpTo(maxExtent);
    await tester.pumpAndSettle();
    for (final section in sections) {
      if (find.text(section).evaluate().isNotEmpty) sectionsSeen.add(section);
    }

    expect(sectionsSeen, containsAll(sections));
  });
}
