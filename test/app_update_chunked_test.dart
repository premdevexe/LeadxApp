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
/// chunked downloader's file I/O runs for real.
class _FakePathProviderPlatform extends MethodChannelPathProvider {
  _FakePathProviderPlatform(this.dir);

  final String dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// A tiny local HTTP server that honours `Range` (like the real portal) so
/// the parallel-slice path is exercised end-to-end, not just its happy-path
/// cache-reuse. Records how many ranged GETs it served so a test can assert
/// the chunked path actually ran.
class _RangeServer {
  _RangeServer(this.bytes);

  final List<int> bytes;
  int rangedGetCount = 0;
  HttpServer? _server;
  int port = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = _server!.port;
    _server!.listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    if (req.method == 'HEAD') {
      req.response.headers.set('Accept-Ranges', 'bytes');
      req.response.headers.contentLength = bytes.length;
      req.response.statusCode = HttpStatus.ok;
      await req.response.close();
      return;
    }

    final range = req.headers.value('range');
    if (range == null) {
      req.response.headers.set('Accept-Ranges', 'bytes');
      req.response.headers.contentLength = bytes.length;
      req.response.statusCode = HttpStatus.ok;
      req.response.add(bytes);
      await req.response.close();
      return;
    }

    rangedGetCount++;
    final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
    final total = bytes.length;
    if (m == null) {
      req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await req.response.close();
      return;
    }
    final start = int.parse(m.group(1)!);
    final end = (m.group(2)!.isEmpty) ? total - 1 : int.parse(m.group(2)!);
    if (start >= total || start > end) {
      req.response.headers.set('Content-Range', 'bytes */$total');
      req.response.statusCode = 416; // Range Not Satisfiable
      await req.response.close();
      return;
    }
    final last = end < total ? end : total - 1;
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers.set('Accept-Ranges', 'bytes');
    req.response.headers.set('Content-Range', 'bytes $start-$last/$total');
    req.response.headers.contentLength = last - start + 1;
    req.response.add(bytes.sublist(start, last + 1));
    await req.response.close();
  }

  Future<void> stop() async => _server?.close(force: true);

  String url() => 'http://127.0.0.1:$port/leadx.apk';
}

/// A server that ignores `Range` and always answers 200 with the full body —
/// the shape of a CDN edge that has no ranged downloads, which must land the
/// file through the single-stream fallback.
class _PlainServer {
  _PlainServer(this.bytes);

  final List<int> bytes;
  HttpServer? _server;
  int port = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = _server!.port;
    _server!.listen((req) async {
      req.response.headers.contentLength = bytes.length;
      req.response.statusCode = HttpStatus.ok;
      if (req.method != 'HEAD') req.response.add(bytes);
      await req.response.close();
    });
  }

  Future<void> stop() async => _server?.close(force: true);

  String url() => 'http://127.0.0.1:$port/leadx.apk';
}

VersionDetails _release({
  required int versionCode,
  required int fileSizeBytes,
  required String checksumSha256,
  required String downloadUrl,
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
    'download_url': downloadUrl,
  }.cast<String, dynamic>());
}

Future<List<int>> _pattern(int n) async {
  final buf = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    buf[i] = i & 0xff;
  }
  return buf;
}

void main() {
  late Directory tempDir;
  late AppUpdateService service;
  late PathProviderPlatform originalPlatform;

  setUp(() {
    originalPlatform = PathProviderPlatform.instance;
    tempDir = Directory.systemTemp.createTempSync('leadx_chunked_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    service = AppUpdateService.instance;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPlatform;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a range-capable server downloads in parallel slices and verifies',
      () async {
    // 16 MB → _chunkCount = 3 slices (well above the 4 MB threshold), so the
    // parallel path is forced, not the single-stream fallback.
    final n = 16 * 1024 * 1024;
    final buf = await _pattern(n);
    final sum = sha256.convert(buf).toString();

    final server = _RangeServer(buf);
    await server.start();
    addTearDown(server.stop);

    final version = _release(
      versionCode: 900,
      fileSizeBytes: n,
      checksumSha256: sum,
      downloadUrl: server.url(),
    );

    final result = await service.download(version: version);

    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.file!.lengthSync(), n);
    expect(sha256.convert(await result.file!.readAsBytes()).toString(), sum,
        reason: 'stitched slices must byte-for-byte match the source');
    // Prove the chunked path ran: 16 MB means 3 slices, so at least 3 ranged
    // GETs. A single-stream download would have served 0.
    expect(server.rangedGetCount, greaterThanOrEqualTo(3));
    // Sidecars must not linger.
    expect(
      tempDir.listSync().where((e) => e.path.contains('.part')),
      isEmpty,
    );
  });

  test('a server that ignores Range still lands the file via the stream',
      () async {
    final n = 1024 * 1024; // small; the fallback is size-agnostic
    final buf = await _pattern(n);
    final sum = sha256.convert(buf).toString();

    final server = _PlainServer(buf);
    await server.start();
    addTearDown(server.stop);

    final version = _release(
      versionCode: 901,
      fileSizeBytes: n,
      checksumSha256: sum,
      downloadUrl: server.url(),
    );

    final result = await service.download(version: version);

    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.file!.lengthSync(), n);
    expect(sha256.convert(await result.file!.readAsBytes()).toString(), sum);
  });

  test('a bad published checksum fails the download, never installs',
      () async {
    final n = 5 * 1024 * 1024;
    final buf = await _pattern(n);
    final server = _RangeServer(buf);
    await server.start();
    addTearDown(server.stop);

    final version = _release(
      versionCode: 902,
      fileSizeBytes: n,
      // A checksum the real bytes will not match.
      checksumSha256: '0' * 64,
      downloadUrl: server.url(),
    );

    final result = await service.download(version: version);
    expect(result.isSuccess, isFalse,
        reason: 'a checksum mismatch must fail the download, not install');
    expect(File('${tempDir.path}/leadx-902.apk').existsSync(), isFalse);
  });
}
