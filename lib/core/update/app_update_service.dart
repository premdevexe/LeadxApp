import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_model.dart';

/// Talks to the self-hosted LeadX Update Portal and installs APKs on Android.
///
/// This is a **separate origin** from the LeadX employee API, so it uses its
/// own bare [Dio] instance: no Bearer token, no retry loop, and short
/// timeouts — an update check must never delay or block app startup.
///
/// Nothing here throws to the caller. Every failure (offline, timeout, 5xx,
/// a malformed body) degrades to `null` / a failed result so the app keeps
/// working and the update flow simply doesn't appear.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// The update portal's origin. Distinct from the `.../api/v1/employee`
  /// backend in [ApiConfig].
  static const String portalBaseUrl =
      'https://updateleadx.cloudaspiresolutions.in';

  /// Where the portal mounts the app-update routes.
  static const String _apiPrefix = '/api/v1/app';

  /// Attached to the APK request so portal analytics can tell the sources
  /// apart. Deliberately generic — no user or employee identifiers.
  static const String _userAgent = 'LeadX-Android-Mobile';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 8),
    headers: const {'Accept': 'application/json'},
    // The update endpoints are unauthenticated; never follow a redirect to
    // somewhere that would hand over the session, just read what's sent.
    followRedirects: true,
    maxRedirects: 3,
  ));

  /// The in-flight chunked slice requests. If the user cancels mid-download,
  /// each of these tokens is cancelled so `Future.wait` inside
  /// [_fetchChunked] unblocks immediately instead of waiting for a socket to
  /// time out.
  final Set<CancelToken> _liveTokens = <CancelToken>{};

  /// Cached platform metadata — reading it hits a method channel, and both
  /// version and package name are needed on every check.
  PackageInfo? _packageInfo;

  Future<PackageInfo> _info() async =>
      _packageInfo ??= await PackageInfo.fromPlatform();

  /// The installed version name, e.g. `2.0.8`. Cheap to read — used by the
  /// Profile footer, so it never rethrows.
  Future<PackageInfo?> packageInfo() async {
    try {
      return await _info();
    } catch (e) {
      debugPrint('[LeadX Update] package info unavailable: $e');
      return null;
    }
  }

  // ── Checking ─────────────────────────────────────────────────────────

  /// Asks the portal whether a newer build exists.
  ///
  /// Returns `null` on any failure so callers can treat "no result" and "no
  /// update" the same way.
  Future<UpdateCheckResult?> checkForUpdate() async {
    try {
      final info = await _info();
      // `buildNumber` is the Android versionCode (`2.0.8+112` → 112).
      final versionCode = int.tryParse(info.buildNumber.trim()) ?? 0;

      final res = await _dio.get<dynamic>(
        '$portalBaseUrl$_apiPrefix/check-update',
        queryParameters: {
          'current_version_code': versionCode,
          'package_name': info.packageName,
        },
      );

      final data = res.data;
      if (data is! Map) {
        debugPrint('[LeadX Update] Unexpected check-update body: $data');
        return null;
      }

      return UpdateCheckResult.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      debugPrint('[LeadX Update] check-update failed: ${e.type} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[LeadX Update] check-update error: $e');
      return null;
    }
  }

  /// Fetches full details for the portal's current release
  /// (`GET /app/latest`). Used for the manual "Check for updates" row.
  Future<VersionDetails?> latestRelease() async {
    try {
      final res = await _dio.get<dynamic>('$portalBaseUrl$_apiPrefix/latest');
      final data = res.data;
      if (data is! Map) return null;
      final payload = data['data'];
      if (payload is! Map) return null;
      return VersionDetails.fromJson(payload.cast<String, dynamic>());
    } catch (e) {
      debugPrint('[LeadX Update] latest release error: $e');
      return null;
    }
  }

  // ── Downloading ──────────────────────────────────────────────────────

  /// How many parallel slices to use for a range-capable download.
  ///
  /// The portal sits on shared hosting, where a *single* connection gets
  /// throttled to a trickle; several concurrent byte-ranges beat it. Slices
  /// are ~8 MB, clamped to 2–8 in flight. Below ~4 MB a plain stream is
  /// just as fast and wastes no connections.
  static int _chunkCount(int sizeBytes) {
    if (sizeBytes < (4 << 20)) return 1;
    final slices = (sizeBytes ~/ (8 << 20)) + 1;
    return slices.clamp(2, 8);
  }

  /// Asks the server for its size and Range support: a HEAD first (cheap),
  /// then a single-byte ranged GET if the HEAD doesn't answer.
  Future<_Probe> _probe(VersionDetails version) async {
    try {
      final head = await _dio.head(
        version.downloadUrl,
        options: Options(headers: {'User-Agent': _userAgent}),
      );
      final declared = int.tryParse(_headerValue(head, 'content-length') ?? '');
      final total = (declared ?? 0) > 0 ? declared! : version.fileSizeBytes;
      final acceptsRanges =
          (_headerValue(head, 'accept-ranges') ?? '').toLowerCase();
      return _Probe(total, acceptsRanges.contains('bytes') && total > 0);
    } on DioException {
      // HEAD not implemented (some CDNs 405 it) — one byte does double
      // duty: a 206 proves Range works *and* reveals the total length in
      // `Content-Range`. A 200 means Range was ignored.
      final res = await _dio.get<dynamic>(
        version.downloadUrl,
        options: Options(
          headers: {'User-Agent': _userAgent, 'Range': 'bytes=0-0'},
          // Single byte; the body is discarded, we only read headers.
          responseType: ResponseType.plain,
        ),
      );
      if (res.statusCode == 206) {
        final total =
            int.tryParse((_headerValue(res, 'content-range') ?? '').split('/').last) ??
                version.fileSizeBytes;
        return _Probe(total, total > 0);
      }
      final total =
          int.tryParse(_headerValue(res, 'content-length') ?? '') ?? version.fileSizeBytes;
      return _Probe(total, false);
    }
  }

  /// Streams the whole file in one connection (the original path) and
  /// returns the byte count the server declared — the caller re-checks it
  /// against the file on disk.
  Future<int> _fetchStream(
    VersionDetails version,
    File partial,
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    final res = await _dio.download(
      version.downloadUrl,
      partial.path,
      cancelToken: cancelToken,
      deleteOnError: true,
      options: Options(
        headers: {'User-Agent': _userAgent},
        // The portal sends `Content-Type: application/vnd.android.package-archive`;
        // Dio's default JSON transformer would otherwise try to decode it.
        responseType: ResponseType.stream,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
      onReceiveProgress: onProgress,
    );
    final declared = int.tryParse(_headerValue(res, 'content-length') ?? '');
    return (declared ?? 0) > 0 ? declared! : version.fileSizeBytes;
  }

  /// Downloads the file as several parallel byte-range slices.
  ///
  /// Each slice streams to its own sidecar file (`<part>.s0`, `.s1`, …) via
  /// Dio's built-in downloader — one file per slice, so the concurrent
  /// writers never contend on a single `RandomAccessFile` handle (Dart's
  /// `FileMode` can't express read+write-without-truncate, which a shared
  /// file would need). Once every slice lands, they are concatenated in
  /// order into [partial] and the sidecars are removed.
  ///
  /// A slice whose connection drops re-requests its whole range (cheap —
  /// a slice is only ~8 MB). If the server stops honouring `Range`
  /// partway through, [_RangeNotHonored] is thrown and the caller recovers
  /// with a single stream.
  Future<void> _fetchChunked({
    required VersionDetails version,
    required int totalBytes,
    required File partial,
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
  }) async {
    final n = _chunkCount(totalBytes);
    final sliceSize = totalBytes ~/ n;

    final sidecars = <File>[
      for (var i = 0; i < n; i++) File('${partial.path}.s$i'),
    ];
    // Drop stale sidecars from a prior interrupted attempt.
    for (final f in sidecars) {
      if (await f.exists()) await _deleteQuietly(f);
    }

    // `dio.download` reports progress relative to the *slice*; convert it to
    // global progress so 8 racing slices add up instead of each starting at 0.
    final sliceReceived = List<int>.filled(n, 0);
    final tracker = _ProgressTracker(totalBytes, onProgress);

    var cancelled = false;
    _liveTokens.clear();
    if (cancelToken != null) {
      cancelToken.whenCancel.then((_) {
        cancelled = true;
        // Wake every in-flight slice request so `Future.wait` unblocks.
        for (final t in _liveTokens) {
          t.cancel('cancelled');
        }
      });
    }

    Future<void> fetchSlice(int i) async {
      final start = i * sliceSize;
      final end = (i + 1 == n) ? totalBytes - 1 : (i + 1) * sliceSize - 1;
      var retries = 0;
      while (true) {
        if (cancelled || (cancelToken?.isCancelled ?? false)) {
          throw _DownloadCancelled();
        }
        final token = CancelToken();
        _liveTokens.add(token);
        try {
          await _dio.download(
            version.downloadUrl,
            sidecars[i].path,
            cancelToken: token,
            deleteOnError: true,
            options: Options(
              headers: {
                'User-Agent': _userAgent,
                'Range': 'bytes=$start-$end',
              },
              responseType: ResponseType.stream,
              // A 206 proves the range was honoured. A 200 means the server
              // ignored the range — the single-stream fallback recovers it.
              validateStatus: (s) => s == 206,
            ),
            onReceiveProgress: (received, total) {
              final delta = received - sliceReceived[i];
              sliceReceived[i] = received;
              if (delta > 0) tracker.add(delta);
            },
          );
          break; // this slice is complete
        } on DioException catch (e) {
          if (CancelToken.isCancel(e) || cancelled) {
            throw _DownloadCancelled();
          }
          if (e.response?.statusCode == 200) {
            throw _RangeNotHonored();
          }
          // Transient drop (timeout, disconnect, 5xx burst): the next loop
          // re-requests the whole slice range. Hard limits: 3 retries, or
          // any 4xx status (404/416 the range itself is wrong).
          final status = e.response?.statusCode;
          if (++retries > 3 ||
              (status != null && status >= 400 && status < 500)) {
            rethrow;
          }
        } finally {
          _liveTokens.remove(token);
        }
      }
    }

    final futures = <Future<void>>[
      for (var i = 0; i < n; i++) fetchSlice(i),
    ];
    try {
      await Future.wait(futures);
    } catch (e) {
      // One slice failed (or the user cancelled): abort the rest so nothing
      // outlives the error with stray requests or writers. The slice
      // files are useless without a complete download, so drop them too.
      for (final t in _liveTokens) {
        t.cancel('aborted');
      }
      for (final f in sidecars) {
        await _deleteQuietly(f);
      }
      rethrow;
    }

    // Every slice landed: stitch them into the staged file, in order.
    final out = partial.openWrite();
    try {
      for (final f in sidecars) {
        await out.addStream(f.openRead());
      }
    } finally {
      await out.close();
    }

    for (final f in sidecars) {
      await _deleteQuietly(f);
    }
  }

  /// Streams the APK into the app's cache directory, hashing as it goes.
  ///
  /// The file is written to a `.part` name and only renamed once the byte
  /// count and SHA-256 both match, so a cancelled or truncated download can
  /// never be handed to the Android packager.
  ///
  /// When the server supports byte ranges (the portal does) the file is
  /// pulled in several parallel slices — shared-hosting per-connection
  /// throttling is what makes a single 59 MB stream crawl, and slicing it
  /// across connections recovers most of that.
  Future<UpdateDownloadResult> download({
    required VersionDetails version,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = 'leadx-${version.versionCode}.apk';
    final target = File('${dir.path}/$fileName');
    final partial = File('${target.path}.part');

    // If a fully-verified copy of this release is already in the cache, reuse
    // it — retrying after a failed install (the installer dialog is only
    // shown once, so installs can genuinely need a second attempt) should
    // not mean re-downloading ~59 MB.
    if (await target.exists()) {
      if (await _isVerified(target, version)) {
        return UpdateDownloadResult.success(target);
      }
      await _deleteQuietly(target); // stale or from an older upload
    }

    try {
      // Drop any leftover partial from an interrupted download —
      // `dio.download` / the chunked writer would otherwise append to it.
      if (await partial.exists()) await partial.delete();

      int expectedBytes;
      final probe = await _probe(version);
      // Only the chunked path when it is actually faster — a single slice
      // just adds a pointless sidecar + copy round-trip.
      if (probe.rangeOk && probe.total > 0 && _chunkCount(probe.total) > 1) {
        try {
          await _fetchChunked(
            version: version,
            totalBytes: probe.total,
            partial: partial,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
          expectedBytes = probe.total;
        } on _RangeNotHonored {
          // The server stopped honouring ranges mid-download; the plain
          // stream below is the safe recovery.
          await _deleteQuietly(partial);
          expectedBytes = await _fetchStream(
            version, partial, cancelToken, onProgress,
          );
        }
      } else {
        expectedBytes = await _fetchStream(
          version, partial, cancelToken, onProgress,
        );
      }

      final actualBytes = await partial.length();

      if (expectedBytes > 0 && actualBytes != expectedBytes) {
        await _deleteQuietly(partial);
        return UpdateDownloadResult.failure(
          'The download stopped early '
          '(${_mib(actualBytes)} of ${_mib(expectedBytes)}). '
          'Check your connection and try again.',
        );
      }

      // Verify before the file is renamed into place, so the only
      // `.apk` that ever exists in cache is a fully-verified one.
      final digest = await _sha256Of(partial);
      if (!_checksumMatches(digest, version.checksumSha256)) {
        await _deleteQuietly(partial);
        return UpdateDownloadResult.failure(
          'Security check failed: the downloaded file does not match the '
          'published checksum. Please try again.',
        );
      }

      if (await target.exists()) await target.delete();
      final installedApk = await partial.rename(target.path);

      // Drop APKs for other releases — only the one we just verified
      // (plus the in-flight `.part`, deleted above on error) should linger.
      await _pruneOtherApks(keep: target);

      return UpdateDownloadResult.success(installedApk);
    } on _DownloadCancelled {
      await _deleteQuietly(partial);
      return UpdateDownloadResult.failure('Download cancelled.', cancelled: true);
    } catch (e) {
      await _deleteQuietly(partial);
      if (e is DioException) {
        // A cancel arrives wrapped as a DioException; the stream path
        // relies on it so "Cancel download" reports as cancelled, not as a
        // server failure.
        if (cancelToken != null && CancelToken.isCancel(e)) {
          return UpdateDownloadResult.failure(
            'Download cancelled.',
            cancelled: true,
          );
        }
        final status = e.response?.statusCode;
        return UpdateDownloadResult.failure(
          status != null
              ? 'The update server responded with HTTP $status. '
                  'Please try again shortly.'
              : 'Could not reach the update server. Check your connection '
                  'and try again.',
        );
      }
      debugPrint('[LeadX Update] download error: $e');
      return UpdateDownloadResult.failure(
        'The update could not be downloaded. Please try again.',
      );
    }
  }

  // ── Installing ───────────────────────────────────────────────────────

  /// Hands a verified APK to Android's package installer.
  ///
  /// On API 26+ this throws up the system "install unknown apps" prompt the
  /// first time; on the second press the installer itself takes over. We
  /// never install silently — the OS dialog is the user's consent.
  Future<InstallResult> install(File apk) async {
    if (!await apk.exists()) {
      return const InstallResult(false, 'The update file is missing. Please download it again.');
    }
    try {
      final result = await OpenFilex.open(
        apk.path,
        type: 'application/vnd.android.package-archive',
      );
      switch (result.type) {
        case ResultType.done:
          return const InstallResult(true, null);
        case ResultType.permissionDenied:
          return const InstallResult(
            false,
            'Android blocked the install. Allow LeadX to install unknown '
            'apps in Settings, then tap Update again.',
          );
        case ResultType.noAppToOpen:
          return const InstallResult(
            false,
            'No package installer is available on this device.',
          );
        case ResultType.fileNotFound:
          return const InstallResult(
            false,
            'The update file is missing. Please download it again.',
          );
        case ResultType.error:
          return InstallResult(false, result.message);
      }
    } catch (e) {
      debugPrint('[LeadX Update] install error: $e');
      return const InstallResult(false, 'Android could not start the installer.');
    }
  }

  /// Removes cached APKs that are no longer needed.
  ///
  /// Note: this must never run while the system installer still needs a file
  /// — Android resolves the install URI lazily, so deleting mid-install breaks
  /// the install ("problem with the app file").
  Future<void> clearCache() async {
    await _pruneOtherApks();
  }

  /// Deletes `leadx-*.apk` / `*.part` / `*.part.s*` files in the cache
  /// directory.
  ///
  /// [keep] (its own path) is spared — a verified APK for the *current*
  /// release is reusable for a retry, so it is only removed once a newer
  /// release supersedes it or the installer has taken over. The `.part`
  /// match also catches the chunked downloader's sidecar slices
  /// (`leadx-<code>.apk.part.s0` …), which must not outlive a download.
  Future<void> _pruneOtherApks({File? keep}) async {
    try {
      final dir = await getTemporaryDirectory();
      // `getTemporaryDirectory()` returns backslash paths on Windows while
      // the download code builds `File('${dir.path}/$name')` — mixed
      // separators would break a naive `==` and let the prune delete the
      // APK that was just verified and renamed. Normalise separators and
      // case (Windows is case-insensitive) before comparing.
      final keepPath =
          keep?.absolute.path.replaceAll(r'\', '/').toLowerCase();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final p = entity.absolute.path.replaceAll(r'\', '/').toLowerCase();
        if (p == keepPath) continue;
        if (p.endsWith('.apk') || p.contains('.apk.part')) {
          await _deleteQuietly(entity);
        }
      }
    } catch (_) {
      // Cache cleanup is best-effort.
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  /// Streams the file through SHA-256 so a 20 MB APK never has to sit in
  /// memory as a single `List<int>`.
  Future<String> _sha256Of(File file) async {
    final output = _DigestCollector();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    final digest = output.digest;
    if (digest == null) {
      throw StateError('SHA-256 produced no digest');
    }
    return digest.toString();
  }

  /// Constant-ish comparison of a computed digest against the portal's
  /// hex string. An empty expected checksum is treated as "unverifiable"
  /// and **fails closed** — a build published without a checksum is not
  /// installed.
  static bool _checksumMatches(String actual, String expected) {
    final want = expected.trim().toLowerCase();
    if (want.isEmpty) return false;
    return actual.trim().toLowerCase() == want;
  }

  /// A cached APK can only be reused when it still verifies against this
  /// release's published size + SHA-256. Files are only ever created after
  /// passing exactly this check, so it is cheap insurance against cache
  /// drift (a re-published release id, a stale copy from an older client).
  Future<bool> _isVerified(File file, VersionDetails version) async {
    if (version.fileSizeBytes > 0 &&
        await file.length() != version.fileSizeBytes) {
      return false;
    }
    return _checksumMatches(await _sha256Of(file), version.checksumSha256);
  }

  static String? _headerValue(Response<dynamic> res, String name) {
    for (final entry in res.headers.map.entries) {
      if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }

  static String _mib(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// What a size/Range probe of the download URL learned.
class _Probe {
  const _Probe(this.total, this.rangeOk);

  /// Total file size in bytes; 0 when nobody declared it.
  final int total;

  /// True when the server is range-capable (answered a ranged request with
  /// 206) and its total length is known.
  final bool rangeOk;
}

/// Marks a download slice that can no longer get a 206 — the server stopped
/// honouring `Range` mid-download (a proxy, a CDN edge change). Caught at the
/// top level, which then recovers with a single stream.
class _RangeNotHonored implements Exception {
  const _RangeNotHonored();

  @override
  String toString() => 'the download server stopped honouring Range requests';
}

/// Marks a user cancel from inside the chunked writer.
class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}

/// Coalesced progress reporting for the chunked path: 8 racing slices call
/// [add] from the same event loop, and the dialog's `setState` only needs a
/// handful of updates a second, not one per chunk.
class _ProgressTracker {
  _ProgressTracker(this.total, this.sink)
      : step = total > 0 ? total ~/ 100 : 1;

  final int total;
  final void Function(int received, int total)? sink;
  final int step;

  int _reported = 0;
  int _done = 0;

  void add(int bytes) {
    _done += bytes;
    if (_done >= _reported + step || _done >= total) {
      _reported = _done >= total ? total : _done;
      sink?.call(_reported, total);
    }
  }
}

/// Outcome of a download attempt.
@immutable
class UpdateDownloadResult {
  const UpdateDownloadResult._({this.file, this.error, this.cancelled = false});

  const UpdateDownloadResult.success(File file) : this._(file: file);

  const UpdateDownloadResult.failure(String error, {bool cancelled = false})
      : this._(error: error, cancelled: cancelled);

  /// The verified, ready-to-install APK. Non-null only on success.
  final File? file;

  /// User-facing reason the download did not produce an installable file.
  final String? error;

  final bool cancelled;

  bool get isSuccess => file != null;
}

/// Outcome of handing the APK to the Android installer.
@immutable
class InstallResult {
  const InstallResult(this.launched, this.error);

  /// True when the system installer activity was started.
  final bool launched;

  final String? error;
}

/// Minimal [Sink] that keeps the single digest emitted by
/// `sha256.startChunkedConversion`.
class _DigestCollector implements Sink<Digest> {
  Digest? _digest;

  Digest? get digest => _digest;

  @override
  void add(Digest value) {
    _digest = value;
  }

  @override
  void close() {}
}