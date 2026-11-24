import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/update/app_update_service.dart';
import 'package:leadx/core/update/update_model.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// The concrete platform class lives in `src/` and is not re-exported; the
// main library is still imported above for the abstract `PathProviderPlatform`.
// ignore: implementation_imports
import 'package:path_provider_platform_interface/src/method_channel_path_provider.dart';

/// Points `getTemporaryDirectory()` at a real scratch directory so the
/// download / cache-reuse logic in [AppUpdateService] runs for real.
class _FakePathProviderPlatform extends MethodChannelPathProvider {
  _FakePathProviderPlatform(this.dir);

  final String dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

VersionDetails _release({
  int versionCode = 119,
  int fileSizeBytes = 0,
  String checksumSha256 = '',
}) {
  return VersionDetails.fromJson({
    'id': versionCode,
    'version_name': '2.0.11',
    'version_code': versionCode,
    'release_title': 't',
    'release_notes': '',
    'file_size_formatted': '',
    'file_size': fileSizeBytes,
    'checksum_sha256': checksumSha256,
    // Unreachable on purpose: a result that succeeds with this URL did so
    // through the cache-reuse path, never a real download.
    'download_url': 'https://unreachable.invalid/api/v1/app/download/$versionCode',
  }.cast<String, dynamic>());
}

void main() {
  late Directory tempDir;
  late AppUpdateService service;
  late PathProviderPlatform originalPlatform;

  setUp(() {
    originalPlatform = PathProviderPlatform.instance;
    tempDir = Directory.systemTemp.createTempSync('leadx_update_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    service = AppUpdateService.instance;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPlatform;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('download cache reuse', () {
    test('reuses a cached, verified APK without fetching', () async {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8];
      final version = _release(
        fileSizeBytes: bytes.length,
        checksumSha256: sha256.convert(bytes).toString(),
      );

      // Pre-seed the exact file `download()` would have produced.
      final cached = File('${tempDir.path}/leadx-119.apk');
      cached.writeAsBytesSync(bytes);

      final result = await service.download(version: version);

      expect(result.isSuccess, isTrue,
          reason: 'a verified cached copy must be reusable, not re-fetched');
      expect(result.file!.path, cached.path);
    });

    test('refetches when the cached file no longer matches the checksum',
        () async {
      final version = _release(
        fileSizeBytes: 100,
        checksumSha256: 'deadbeef',
      );
      File('${tempDir.path}/leadx-119.apk').writeAsBytesSync(List.filled(100, 0));

      // Cache is stale → the unreachable URL is attempted → the result must
      // be a failure, never the stale file.
      final result = await service.download(version: version);
      expect(result.isSuccess, isFalse);
    });

    test('fails closed when the release has no published checksum', () async {
      final version = _release(); // no size, no checksum
      File('${tempDir.path}/leadx-119.apk').writeAsBytesSync([1]);

      final result = await service.download(version: version);
      expect(result.isSuccess, isFalse);
    });
  });

  group('clearCache', () {
    test('removes cached APKs', () async {
      File('${tempDir.path}/leadx-118.apk').writeAsBytesSync([0]);
      File('${tempDir.path}/leadx-119.apk').writeAsBytesSync([1]);

      await service.clearCache();

      expect(File('${tempDir.path}/leadx-118.apk').existsSync(), isFalse);
      expect(File('${tempDir.path}/leadx-119.apk').existsSync(), isFalse);
    });
  });
}
