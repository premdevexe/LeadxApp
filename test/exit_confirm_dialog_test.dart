import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/shared/widgets/exit_confirm_dialog.dart';

void main() {
  group('ExitConfirmationDialog Tests', () {
    testWidgets('renders title, message, and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExitConfirmationDialog(
              title: 'Exit LeadX?',
              message: 'Are you sure you want to exit?',
            ),
          ),
        ),
      );

      expect(find.text('Exit LeadX?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
    });

    testWidgets('tapping Cancel returns false and pops dialog', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await ExitConfirmationDialog.show(context);
                  },
                  child: const Text('Open Exit Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Exit Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('tapping Exit App returns true and pops dialog', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await ExitConfirmationDialog.show(context);
                  },
                  child: const Text('Open Exit Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Exit Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsOneWidget);

      await tester.tap(find.text('Exit App'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('ExitConfirmScope wraps child and handles non-root pop callback',
        (tester) async {
      bool nonRootHandled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExitConfirmScope(
              onBackNonRoot: () {
                nonRootHandled = true;
                return true;
              },
              child: const Text('Root Content'),
            ),
          ),
        ),
      );

      expect(find.text('Root Content'), findsOneWidget);

      // Simulate a back button press
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(nonRootHandled, isTrue);
      expect(find.byType(ExitConfirmationDialog), findsNothing);
    });
  });
}
