/// Response models for the LeadX Update Portal
/// (`https://updateleadx.cloudaspiresolutions.in/api/v1/app/*`).
///
/// The portal is a separate service from the LeadX employee API, so these
/// models are deliberately self-contained — they never touch [ApiClient] and
/// parse tolerantly (`intFromJson` / `numFromJson`) because Laravel casts
/// version codes as either numbers or numeric strings depending on the
/// resource.
library;

import '../../shared/models/json_helpers.dart';

/// Result of `GET /app/check-update`.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    required this.updateType,
    required this.isSupported,
    required this.currentInstalledVersionCode,
    required this.minSupportedVersionCode,
    required this.prompt,
    this.latestVersion,
  });

  final bool updateAvailable;

  /// `'optional'` | `'mandatory'` | `'none'` — as decided by the portal.
  final String updateType;

  /// False once the installed build has dropped below
  /// [minSupportedVersionCode]; the portal also folds this into
  /// [updateType] but the app never trusts one field alone.
  final bool isSupported;

  final int currentInstalledVersionCode;
  final int minSupportedVersionCode;
  final VersionDetails? latestVersion;
  final UpdatePrompt prompt;

  /// A mandatory update can never be dismissed or postponed. Both signals are
  /// honoured so a portal that forgets to set `update_type` (but does mark the
  /// build unsupported) still blocks the app.
  bool get isMandatory => !isSupported || updateType == 'mandatory';

  /// True when there is both an update and something actionable to install.
  /// A "mandatory" response with no release attached would otherwise trap the
  /// user behind an undismissable sheet with no way forward.
  bool get isActionable =>
      updateAvailable && (latestVersion?.downloadUrl.isNotEmpty ?? false);

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['latest_version'];
    return UpdateCheckResult(
      updateAvailable: json['update_available'] == true,
      updateType: (json['update_type'] ?? 'none').toString().toLowerCase(),
      isSupported: json['is_supported'] != false,
      currentInstalledVersionCode: intFromJson(json['current_installed_version_code']) ?? 0,
      minSupportedVersionCode: intFromJson(json['min_supported_version_code']) ?? 0,
      latestVersion: rawVersion is Map
          ? VersionDetails.fromJson(rawVersion.cast<String, dynamic>())
          : null,
      prompt: UpdatePrompt.fromJson(json['prompt']),
    );
  }
}

/// The release the portal is currently serving.
class VersionDetails {
  const VersionDetails({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.fileSizeFormatted,
    required this.fileSizeBytes,
    required this.checksumSha256,
    required this.downloadUrl,
  });

  final int id;
  final String versionName;
  final int versionCode;
  final String releaseTitle;
  final String releaseNotes;
  final String fileSizeFormatted;
  final int fileSizeBytes;
  final String checksumSha256;
  final String downloadUrl;

  /// "20.9 MB" — falls back to the raw byte count when the portal omits the
  /// pre-formatted size.
  String get readableSize {
    if (fileSizeFormatted.trim().isNotEmpty) return fileSizeFormatted.trim();
    if (fileSizeBytes <= 0) return 'Unknown size';
    final mb = fileSizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  factory VersionDetails.fromJson(Map<String, dynamic> json) => VersionDetails(
        id: intFromJson(json['id']) ?? 0,
        versionName: (json['version_name'] ?? '').toString(),
        versionCode: intFromJson(json['version_code']) ?? 0,
        releaseTitle: (json['release_title'] ?? '').toString(),
        releaseNotes: (json['release_notes'] ?? '').toString(),
        fileSizeFormatted: (json['file_size_formatted'] ?? '').toString(),
        fileSizeBytes: intFromJson(json['file_size']) ?? 0,
        checksumSha256: (json['checksum_sha256'] ?? '').toString(),
        downloadUrl: (json['download_url'] ?? '').toString(),
      );
}

/// The server-authored copy shown at the top of the update sheet.
class UpdatePrompt {
  const UpdatePrompt({
    required this.title,
    required this.message,
    required this.mandatory,
  });

  final String title;
  final String message;
  final bool mandatory;

  factory UpdatePrompt.fromJson(dynamic raw) {
    final json = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
    return UpdatePrompt(
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? 'Update Available'
          : json['title'].toString(),
      message: (json['message'] ?? '').toString().trim().isEmpty
          ? 'A new version of LeadX is available.'
          : json['message'].toString(),
      mandatory: json['mandatory'] == true,
    );
  }
}
