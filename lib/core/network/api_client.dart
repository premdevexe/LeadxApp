import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../core/storage/secure_token_storage.dart';

/// Centralized Dio client for the LeadX employee API.
///
/// - Base URL resolved per environment with a user override ([ApiConfig]).
/// - Bearer token attached from secure storage on every request; on 401 the
///   session is cleared and [setUnauthorizedCallback] fires so the UI forces
///   re-login.
/// - Transient failures (network / timeout / 429 / 5xx) are retried with a
///   small backoff.
/// - Idempotency-key support for safe (non-duplicated) order creation.
///
/// All public methods return a normalized `Map<String, dynamic>` body and
/// throw a typed [ApiException] on failure.
class ApiClient {
  ApiClient._()
    : _dio = Dio(
        BaseOptions(
          contentType: Headers.jsonContentType,
          headers: const {
            'Accept': 'application/json',
          },
          receiveDataWhenStatusError: true,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  static final ApiClient shared = ApiClient._();

  final Dio _dio;
  final ErrorParser _errors = const ErrorParser();
  static const int _maxRetries = 2;

  /// Swappable callback fired on a 401 (revoked/expired token).
  void Function() _onUnauthorized = () {};

  void setUnauthorizedCallback(void Function() cb) => _onUnauthorized = cb;

  Future<Map<String, dynamic>> _execute(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{
      'Accept': 'application/json',
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final options = Options(method: method.toUpperCase(), headers: headers);

    var attempt = 0;
    while (true) {
      try {
        // Per-request base URL (env override) + the current Bearer token.
        final token = await SecureTokenStorage.readToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        _dio.options.baseUrl = await _baseUrl();

        final res = await _dio.request<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: options,
        );
        return _body(res);
      } on DioException catch (e) {
        final ex = e.toApiException(_errors);

        if (ex.isUnauthorized) {
          await SecureTokenStorage.setSessionActive(false);
          _onUnauthorized();
          throw ex;
        }

        if (ex.isRetryable && attempt < _maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }
        throw ex;
      }
    }
  }

  Future<String> _baseUrl() => ApiConfig.baseUrl();

  Map<String, dynamic> _body(Response<dynamic> res) {
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    if (res.data is Map) {
      return (res.data as Map).map((k, v) => MapEntry(k.toString(), v));
    }
    return {'data': res.data};
  }

  // ---- Public verb helpers ----
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _execute('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? idempotencyKey,
  }) => _execute(
    'POST',
    path,
    body: data,
    query: query,
    idempotencyKey: idempotencyKey,
  );

  Future<Map<String, dynamic>> put(String path, {Object? data}) =>
      _execute('PUT', path, body: data);

  Future<Map<String, dynamic>> delete(String path, {Object? data}) =>
      _execute('DELETE', path, body: data);
}

/// Convert a [DioException] to a typed [ApiException].
extension DioExceptionX on DioException {
  ApiException toApiException(ErrorParser parser) {
    final parsed = parser.parse(response?.data);
    final status = response?.statusCode;

    var network = false;
    var timeout = false;
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        timeout = true;
        break;
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        network = true;
        break;
      case DioExceptionType.unknown:
        final errStr = (error?.toString() ?? message ?? '').toLowerCase();
        if (errStr.contains('socket') ||
            errStr.contains('handshake') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('network') ||
            errStr.contains('connection') ||
            errStr.contains('clientexception') ||
            errStr.contains('os error')) {
          network = true;
        }
        break;
      default:
        break;
    }

    String finalMessage;
    if (status == null) {
      finalMessage = timeout
          ? 'Connection timed out. Check your network.'
          : (network
              ? 'No network connection. Please check your internet.'
              : 'Could not connect to the server.');
    } else {
      if (parsed.key.isNotEmpty && parsed.key != 'Something went wrong.') {
        finalMessage = parsed.key;
      } else if (status == 401) {
        finalMessage = 'Invalid credentials or inactive account.';
      } else if (status == 403) {
        finalMessage = 'Access forbidden. You do not have permission.';
      } else if (status == 404) {
        finalMessage = 'Requested resource not found.';
      } else if (status == 419) {
        finalMessage = 'Session expired. Please try again.';
      } else if (status == 422) {
        finalMessage = parsed.value.isNotEmpty
            ? parsed.value.values.first.first
            : 'Validation failed. Please verify your credentials.';
      } else if (status == 429) {
        finalMessage = 'Too many requests. Please wait a few minutes.';
      } else if (status >= 500) {
        finalMessage = 'Server error ($status). Please try again later.';
      } else {
        finalMessage = 'Request failed ($status). Please try again.';
      }
    }

    return ApiException(
      statusCode: status,
      message: finalMessage,
      fieldErrors: parsed.value,
      isNetwork: network,
      isTimeout: timeout,
    );
  }
}
