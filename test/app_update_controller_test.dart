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
  });
}