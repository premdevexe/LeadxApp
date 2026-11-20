import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/design/lead_glass.dart';

void main() {
  group('LeadGlass.segmentBar Widget Tests', () {
    testWidgets('renders all tabs and handles tap selection cleanly', (tester) async {
      int selected = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return LeadGlass.segmentBar(
                  context,
                  const ['All', 'Still facing', 'Fixed'],
                  selected,
                  (index) => setState(() => selected = index),
                );
              },
            ),
          ),
        ),
      );

      // Verify all labels are rendered
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Still facing'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);

      // Tap on 'Fixed' (index 2)
      await tester.tap(find.text('Fixed'));
      await tester.pumpAndSettle();

      expect(selected, 2);

      // Tap on 'All' (index 0)
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(selected, 0);
    });
  });
}
