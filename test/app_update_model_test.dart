import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/update/update_model.dart';

void main() {
  group('UpdateCheckResult parsing', () {
    test('parses an optional update payload', () {
      final result = UpdateCheckResult.fromJson({
        'status': 'success',
        'update_available': true,
        'update_type': 'optional',
        'is_supported': true,
        'current_installed_version_code': 100,
        'min_supported_version_code': 100,
        'latest_version': {
          'id': 3,
          'version_name': '1.2.0',
          'version_code': 110,
          'min_version_code': 105,
          'release_title': 'Geolocation',
          'release_notes': '• Live check-in\n• Push alerts',
          'release_date': '2026-11-20T10:15:00+00:00',
          'file_size': 20340890,
          'file_size_formatted': '19.4 MB',
          'checksum_sha256': 'ABC123',
          'download_url': 'https://example.test/api/v1/app/download/3',
        },
        'prompt': {
          'title': 'New LeadX Update Available',
          'message': 'Update to keep receiving alerts.',
          'mandatory': false,
        },
      });

      expect(result.updateAvailable, isTrue);
      expect(result.updateType, 'optional');
      expect(result.isMandatory, isFalse);
      expect(result.isActionable, isTrue);
      expect(result.latestVersion?.versionName, '1.2.0');
      expect(result.latestVersion?.versionCode, 110);
      expect(result.latestVersion?.readableSize, '19.4 MB');
      expect(result.prompt.title, 'New LeadX Update Available');
      expect(result.prompt.mandatory, isFalse);
    });

    test('an unsupported build forces mandatory even without the flag', () {
      final result = UpdateCheckResult.fromJson({
        'update_available': true,
        'update_type': 'optional',
        'is_supported': false,
        'min_supported_version_code': 105,
        'current_installed_version_code': 95,
        'latest_version': {
          'version_code': 110,
          'download_url': 'https://example.test/apk',
        },
        'prompt': {'title': 'Critical Update Required', 'mandatory': false},
      });

      expect(result.isMandatory, isTrue);
    });

    test('version codes arriving as numeric strings still parse', () {
      final result = UpdateCheckResult.fromJson({
        'update_available': 1,
        'update_type': 'MANDATORY',
        'is_supported': true,
        'current_installed_version_code': '112',
        'min_supported_version_code': '105',
        'latest_version': {'version_code': '120', 'file_size': '20340890'},
      });

      expect(result.currentInstalledVersionCode, 112);
      expect(result.minSupportedVersionCode, 105);
      expect(result.latestVersion?.versionCode, 120);
      expect(result.latestVersion?.fileSizeBytes, 20340890);
      // Case-insensitive: the portal's enum is normalised.
      expect(result.isMandatory, isTrue);
      // No prompt block → sensible defaults.
      expect(result.prompt.title, 'Update Available');
    });

    test('no-update payload is not actionable', () {
      final result = UpdateCheckResult.fromJson({
        'update_available': false,
        'update_type': 'none',
        'is_supported': true,
        'current_installed_version_code': 112,
        'min_supported_version_code': 100,
        'latest_version': {'version_code': 112, 'download_url': 'https://x/y'},
      });
      expect(result.isActionable, isFalse);
      expect(result.isMandatory, isFalse);
    });

    test('an available update without a download url is not actionable', () {
      // Guards against a portal misconfiguration trapping the user behind a
      // mandatory sheet that has nothing to install.
      final result = UpdateCheckResult.fromJson({
        'update_available': true,
        'update_type': 'mandatory',
        'is_supported': false,
        'latest_version': {'version_code': 120, 'download_url': ''},
      });
      expect(result.isMandatory, isTrue);
      expect(result.isActionable, isFalse);
    });

    test('malformed body degrades to a no-update result', () {
      final result = UpdateCheckResult.fromJson(const {});
      expect(result.updateAvailable, isFalse);
      expect(result.isActionable, isFalse);
      expect(result.latestVersion, isNull);
      expect(result.prompt.message, 'A new version of LeadX is available.');
    });
  });

  group('VersionDetails.readableSize', () {
    test('prefers the server-formatted size', () {
      const v = VersionDetails(
        id: 1,
        versionName: '2.0.8',
        versionCode: 112,
        releaseTitle: '',
        releaseNotes: '',
        fileSizeFormatted: '19.4 MB',
        fileSizeBytes: 20340890,
        checksumSha256: '',
        downloadUrl: '',
      );
      expect(v.readableSize, '19.4 MB');
    });

    test('falls back to a byte-derived size', () {
      const v = VersionDetails(
        id: 1,
        versionName: '2.0.8',
        versionCode: 112,
        releaseTitle: '',
        releaseNotes: '',
        fileSizeFormatted: '',
        fileSizeBytes: 5242880,
        checksumSha256: '',
        downloadUrl: '',
      );
      expect(v.readableSize, '5.0 MB');
    });
  });
}