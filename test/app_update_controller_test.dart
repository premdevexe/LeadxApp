import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/update/app_update_controller.dart';
import 'package:leadx/core/update/update_model.dart';

UpdateCheckResult _result({
  required bool available,
  String type = 'optional',
  bool supported = true,
  int versionCode = 120,
  String downloadUrl = 'https://update.test/api/v1/app/download/9',
}) =>
    UpdateCheckResult.fromJson({
      'update_available': available,
      'update_type': type,
      'is_supported': supported,
      'current_installed_version_code': 112,
      'min_supported_version_code': supported ? 100 : 120,
      'latest_version': {
        'id': 9,
        'version_name': '2.0.9',
        'version_code': versionCode,
        'download_url': downloadUrl,
      },
      'prompt': {'title': 'Update Available', 'mandatory': type == 'mandatory'},
    });

void main() {
  group('AppUpdateController', () {
    test('surfaces an available update once the check resolves', () async {
      final controller = AppUpdateController(
        checker: () async => _result(available: true),
      );
      addTearDown(controller.dispose);

      expect(controller.shouldPrompt(), isFalse, reason: 'nothing checked yet');
      await controller.checkNow();

      expect(controller.hasPendingUpdate, isTrue);
      expect(controller.isMandatory, isFalse);
      expect(controller.shouldPrompt(), isTrue);
    });

    test('a dismissed optional prompt does not come back', () async {
      final controller = AppUpdateController(
        checker: () async => _result(available: true),
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      controller.dismissPrompt(120);
      expect(controller.shouldPrompt(), isFalse);
    });

    test('a NEW optional build re-prompts after a dismissal', () async {
      var versionCode = 120;
      final controller = AppUpdateController(
        checker: () async => _result(available: true, versionCode: versionCode),
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      controller.dismissPrompt(versionCode);

      versionCode = 121;
      await controller.checkNow();
      expect(controller.shouldPrompt(), isTrue);
    });

    test('a mandatory prompt always comes back after dismissal', () async {
      final controller = AppUpdateController(
        checker: () async => _result(
          available: true,
          type: 'mandatory',
          supported: false,
        ),
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      controller.dismissPrompt(120);

      expect(controller.isMandatory, isTrue);
      expect(controller.shouldPrompt(), isTrue);
    });

    test('a failed check leaves no pending update and does not throw', () async {
      final controller = AppUpdateController(checker: () async => null);
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(controller.result, isNull);
      expect(controller.shouldPrompt(), isFalse);
    });

    test('no-update response never prompts', () async {
      final controller = AppUpdateController(
        checker: () async => _result(available: false),
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(controller.hasPendingUpdate, isFalse);
      expect(controller.shouldPrompt(), isFalse);
    });

    test('notifies listeners when a check completes', () async {
      final controller = AppUpdateController(
        checker: () async => _result(available: true),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.checkNow();
      // One notify as the check starts, one when it lands.
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('triggers onUpdateAvailable when an actionable update lands', () async {
      UpdateCheckResult? capturedResult;
      final controller = AppUpdateController(
        checker: () async => _result(available: true),
        onUpdateAvailable: (res) async => capturedResult = res,
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(capturedResult, isNotNull);
      expect(capturedResult!.latestVersion?.versionCode, equals(120));
    });

    test('does not trigger onUpdateAvailable when update_available is false', () async {
      var called = false;
      final controller = AppUpdateController(
        checker: () async => _result(available: false),
        onUpdateAvailable: (_) async => called = true,
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(called, isFalse);
    });

    test('does not trigger onUpdateAvailable after optional prompt dismissed', () async {
      var callCount = 0;
      final controller = AppUpdateController(
        checker: () async => _result(available: true, versionCode: 120),
        onUpdateAvailable: (_) async => callCount++,
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(callCount, equals(1));

      controller.dismissPrompt(120);
      await controller.checkNow();
      expect(callCount, equals(1));
    });

    test('triggers onUpdateAvailable only ONCE per version across multiple repeated checks', () async {
      var callCount = 0;
      var currentVersion = 120;
      final controller = AppUpdateController(
        checker: () async => _result(available: true, versionCode: currentVersion),
        onUpdateAvailable: (_) async => callCount++,
      );
      addTearDown(controller.dispose);

      // Simulate 5 checks in a row (e.g. interval checks or resumes)
      await controller.checkNow();
      await controller.checkNow();
      await controller.checkNow();
      await controller.checkNow();
      await controller.checkNow();

      // Must be called exactly ONCE for build 120
      expect(callCount, equals(1));
      expect(controller.lastNotifiedVersionCode, equals(120));

      // Now a new version arrives
      currentVersion = 121;
      await controller.checkNow();

      // Now called once more for build 121
      expect(callCount, equals(2));
      expect(controller.lastNotifiedVersionCode, equals(121));

      // Repeated checks on build 121 do not trigger again
      await controller.checkNow();
      expect(callCount, equals(2));
    });

    test('skips onUpdateAvailable if initial lastNotifiedVersionCode matches latest build', () async {
      var callCount = 0;
      final controller = AppUpdateController(
        lastNotifiedVersionCode: 120,
        checker: () async => _result(available: true, versionCode: 120),
        onUpdateAvailable: (_) async => callCount++,
      );
      addTearDown(controller.dispose);

      await controller.checkNow();
      expect(callCount, equals(0), reason: 'already notified in previous session');
    });
  });
}