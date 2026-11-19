/// Typed failure carrying the HTTP status, a user-facing message, and (for
/// 422s) per-field validation errors.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final bool isNetwork;
  final bool isTimeout;

  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetwork = false,
    this.isTimeout = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;

  bool get isRetryable =>
      isNetwork || isTimeout || statusCode == 429 || (statusCode != null && statusCode! >= 500);

  @override
  String toString() =>
      'ApiException(${statusCode ?? 'net'}, $message${fieldErrors.isNotEmpty ? ', fields: ${fieldErrors.keys.join(', ')}' : ''})';
}

/// Extracts the human message + field errors from a Laravel JSON error body.
class ErrorParser {
  const ErrorParser();

  /// Laravel returns either `{ message, errors: {field: [..]} }` (422/401)
  /// or `{ message: string }` (403/404/etc), or `{ error: string }`.
  MapEntry<String, Map<String, List<String>>> parse(dynamic body) {
    String message = 'Something went wrong.';
    final fieldErrors = <String, List<String>>{};

    if (body is Map) {
      final raw = body['message'];
      if (raw is String && raw.trim().isNotEmpty) {
        message = raw.trim();
      } else {
        final err = body['error'];
        if (err is String && err.trim().isNotEmpty) {
          message = err.trim();
        } else {
          final detail = body['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail.trim();
          }
        }
      }

      final errors = body['errors'];
      if (errors is Map) {
        errors.forEach((k, v) {
          final key = k.toString();
          if (v is List) {
            final list = v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
            if (list.isNotEmpty) fieldErrors[key] = list;
          } else if (v is String && v.isNotEmpty) {
            fieldErrors[key] = [v];
          }
        });
      }

      if (message == 'Something went wrong.' && fieldErrors.isNotEmpty) {
        message = fieldErrors.values.first.first;
      }
    } else if (body is String && body.trim().isNotEmpty) {
      final trimmed = body.trim();
      if (!trimmed.startsWith('<') && trimmed.length <= 150) {
        message = trimmed;
      }
    }

    return MapEntry(message, fieldErrors);
  }
}
