import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/shared/widgets/app_snackbar.dart';

void main() {
  group('AppSnackBar Widget & Unit Tests', () {
    testWidgets('creates a valid floating Material SnackBar with correct defaults',
        (tester) async {
      late SnackBar snackBar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                snackBar = AppSnackBar.create(
                  context: context,
                  title: 'Order Status',
                  message: 'Order #1042 approved successfully',
                  type: AppSnackBarType.success,
                  actionLabel: 'UNDO',
                  onAction: () {},
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.showCloseIcon, isTrue);
      expect(snackBar.duration, const Duration(seconds: 4));
      expect(snackBar.action?.label, 'UNDO');
      expect(snackBar.shape, isA<RoundedRectangleBorder>());
    });

    testWidgets('shows SnackBar and displays title, message, and icon on screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showSuccess(
                      context,
                      'Payment received',
                      title: 'Success',
                    );
                  },
                  child: const Text('Show SnackBar'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pumpAndSettle();

      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Payment received'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('executes action callback when action button is tapped',
        (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.show(
                      context,
                      message: 'Item removed',
                      type: AppSnackBarType.warning,
                      actionLabel: 'RESTORE',
                      onAction: () => actionTapped = true,
                    );
                  },
                  child: const Text('Trigger Warning'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Warning'));
      await tester.pumpAndSettle();

      expect(find.text('RESTORE'), findsOneWidget);
      await tester.tap(find.text('RESTORE'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });

    testWidgets('handles error and info variants cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => AppSnackBar.showError(
                        context,
                        'Server timeout',
                        title: 'Error',
                      ),
                      child: const Text('Show Error'),
                    ),
                    ElevatedButton(
                      onPressed: () => AppSnackBar.showInfo(
                        context,
                        'New update pending',
                        title: 'Info',
                      ),
                      child: const Text('Show Info'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();
      expect(find.text('Server timeout'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);

      await tester.tap(find.text('Show Info'));
      await tester.pumpAndSettle();
      expect(find.text('New update pending'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });
}
