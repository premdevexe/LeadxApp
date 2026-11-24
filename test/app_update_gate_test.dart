import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/update/app_update_controller.dart';
import 'package:leadx/core/update/update_dialog.dart';
import 'package:leadx/core/update/update_gate.dart';
import 'package:leadx/core/update/update_model.dart';
import 'package:provider/provider.dart';

UpdateCheckResult _update({String type = 'optional', bool supported = true}) =>
    UpdateCheckResult.fromJson({
      'update_available': true,
      'update_type': type,
      'is_supported': supported,
      'current_installed_version_code': 112,
      'min_supported_version_code': supported ? 100 : 120,
      'latest_version': {
        'id': 9,
        'version_name': '2.0.9',
        'version_code': 120,
        'release_title': 'LeadX v2.0.9',
        'release_notes': 'Bug fixes',
        'file_size_formatted': '19.4 MB',
        'checksum_sha256': 'abc',
        'download_url': 'https://update.test/api/v1/app/download/9',
      },
      'prompt': {
        'title': 'Update Available',
        'message': 'A newer build is ready.',
        'mandatory': type == 'mandatory',
      },
    });

/// Mounts the gate over a stub shell and returns the controller.
///
/// Registers a teardown that unmounts the tree *before* disposing the
/// controller: `UpdateGate.dispose()` stops the controller's periodic check
/// timer, and disposing in the wrong order leaves that timer pending, which
/// trips the test binding's "A Timer is still pending" invariant.
Future<AppUpdateController> _mount(
  WidgetTester tester, {
  required Future<UpdateCheckResult?> Function() checker,
}) async {
  final controller = AppUpdateController(checker: checker);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<AppUpdateController>.value(
      value: controller,
      child: const MaterialApp(
        home: UpdateGate(child: Scaffold(body: Center(child: Text('shell')))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('UpdateGate', () {
    testWidgets('starting a check inside build does not notify mid-build',
        (tester) async {
      // Regression: `start()` used to be invoked from `didChangeDependencies`
      // and notified its Provider scope synchronously, which threw
      // "setState() or markNeedsBuild() called during build".
      await _mount(tester, checker: () async => _update());

      expect(tester.takeException(), isNull);
      expect(find.text('shell'), findsOneWidget);
    });

    testWidgets('presents the sheet once the check lands', (tester) async {
      await _mount(tester, checker: () async => _update());

      expect(tester.takeException(), isNull);
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.text('Update Available'), findsOneWidget);
    });

    testWidgets('an up-to-date response shows nothing', (tester) async {
      await _mount(
        tester,
        checker: () async => UpdateCheckResult.fromJson({
          'update_available': false,
          'update_type': 'none',
          'is_supported': true,
        }),
      );

      expect(find.byType(UpdateDialog), findsNothing);
      expect(find.text('shell'), findsOneWidget);
    });

    testWidgets('a failed check leaves the shell usable', (tester) async {
      await _mount(tester, checker: () async => null);

      expect(tester.takeException(), isNull);
      expect(find.byType(UpdateDialog), findsNothing);
      expect(find.text('shell'), findsOneWidget);
    });

    testWidgets('an optional update is dismissed by Later and stays gone',
        (tester) async {
      final controller = await _mount(tester, checker: () async => _update());
      expect(find.byType(UpdateDialog), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsNothing);

      // A second check for the same build must not re-raise the sheet.
      await controller.checkNow();
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsNothing);
    });

    testWidgets('a mandatory update has no Later button', (tester) async {
      await _mount(
        tester,
        checker: () async => _update(type: 'mandatory', supported: false),
      );

      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Update now'), findsOneWidget);
      expect(find.text('REQUIRED'), findsOneWidget);
    });

    testWidgets('the sheet renders release notes and download size',
        (tester) async {
      await _mount(tester, checker: () async => _update());

      expect(find.text('Bug fixes'), findsOneWidget);
      expect(find.text('19.4 MB'), findsOneWidget);
      expect(find.text('Version 2.0.9 · build 120'), findsOneWidget);
    });

    testWidgets('re-checks for updates on AppLifecycleState.resumed',
        (tester) async {
      var checkCount = 0;
      await _mount(
        tester,
        checker: () async {
          checkCount++;
          return _update();
        },
      );

      // Initial check on mount
      expect(checkCount, equals(1));

      // Simulate app resume (user opening/returning to the app)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(checkCount, equals(2));
    });
  });
}