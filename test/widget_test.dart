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

    // The palette's category tree is a scrollable list — items below the
    // fold aren't mounted until scrolled into view.
    final palette = find.byType(ListView).first;
    await tester.dragUntilVisible(find.text('Controllers'), palette, const Offset(0, -100));
    expect(find.text('Controllers'), findsOneWidget);

    await tester.dragUntilVisible(find.text('Generic Holes'), palette, const Offset(0, -100));
    expect(find.text('Power Supplies'), findsOneWidget);
    expect(find.text('Generic Holes'), findsOneWidget);
  });
}
