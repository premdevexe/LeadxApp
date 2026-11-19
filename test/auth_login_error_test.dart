import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadx/core/errors/api_exception.dart';
import 'package:leadx/core/network/api_client.dart';
import 'package:leadx/shared/models/employee.dart';

void main() {
  group('ErrorParser tests', () {
    const parser = ErrorParser();

    test('parses Laravel standard 422 error body with message and errors map', () {
      final res = parser.parse({
        'message': 'The provided credentials do not match our records.',
        'errors': {
          'login': ['The provided credentials do not match our records.'],
        },
      });

      expect(res.key, 'The provided credentials do not match our records.');
      expect(res.value['login'], contains('The provided credentials do not match our records.'));
    });

    test('extracts error field when message is missing', () {
      final res = parser.parse({
        'error': 'Unauthorized account access',
      });
      expect(res.key, 'Unauthorized account access');
    });

    test('extracts detail field when message and error are missing', () {
      final res = parser.parse({
        'detail': 'Account is suspended',
      });
      expect(res.key, 'Account is suspended');
    });

    test('extracts first field error when message is absent or generic', () {
      final res = parser.parse({
        'errors': {
          'password': ['Password is required.'],
        },
      });
      expect(res.key, 'Password is required.');
      expect(res.value['password'], contains('Password is required.'));
    });

    test('uses short plain string body as message', () {
      final res = parser.parse('Service Temporarily Unavailable');
      expect(res.key, 'Service Temporarily Unavailable');
    });

    test('falls back safely when body is HTML redirect or page', () {
      final res = parser.parse('<!DOCTYPE html><html><head><title>Redirecting</title></head></html>');
      expect(res.key, 'Something went wrong.');
    });
  });

  group('DioExceptionX conversion tests', () {
    const parser = ErrorParser();

    test('handles 422 Unprocessable Entity with validation message', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/employee/login'),
          statusCode: 422,
          data: {
            'message': 'The provided credentials do not match our records.',
            'errors': {
              'login': ['The provided credentials do not match our records.'],
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.statusCode, 422);
      expect(apiEx.isValidation, true);
      expect(apiEx.message, 'The provided credentials do not match our records.');
      expect(apiEx.fieldErrors['login']?.first, 'The provided credentials do not match our records.');
    });

    test('handles 302 HTML response by providing actionable error message instead of Something went wrong', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/employee/login'),
          statusCode: 302,
          data: '<!DOCTYPE html><html>Redirecting...</html>',
        ),
        type: DioExceptionType.badResponse,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.statusCode, 302);
      expect(apiEx.message, 'Request failed (302). Please try again.');
    });

    test('handles 401 Unauthorized', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/employee/me'),
          statusCode: 401,
          data: null,
        ),
        type: DioExceptionType.badResponse,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.isUnauthorized, true);
      expect(apiEx.message, 'Invalid credentials or inactive account.');
    });

    test('handles 429 Too Many Requests', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/employee/login'),
          statusCode: 429,
          data: null,
        ),
        type: DioExceptionType.badResponse,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.statusCode, 429);
      expect(apiEx.message, 'Too many requests. Please wait a few minutes.');
    });

    test('handles 500 Server Error with HTML body', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/employee/login'),
          statusCode: 500,
          data: '<!DOCTYPE html>Server Error</html>',
        ),
        type: DioExceptionType.badResponse,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.statusCode, 500);
      expect(apiEx.message, 'Server error (500). Please try again later.');
    });

    test('detects connection failure in unknown type with socket error', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        type: DioExceptionType.unknown,
        error: 'SocketException: OS Error: Connection refused, errno = 111',
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.isNetwork, true);
      expect(apiEx.message, 'No network connection. Please check your internet.');
    });

    test('detects timeout errors', () {
      final dioEx = DioException(
        requestOptions: RequestOptions(path: '/employee/login'),
        type: DioExceptionType.connectionTimeout,
      );

      final apiEx = dioEx.toApiException(parser);
      expect(apiEx.isTimeout, true);
      expect(apiEx.message, 'Connection timed out. Check your network.');
    });
  });

  group('MeResponse dynamic cast safety', () {
    test('MeResponse dynamic cast safety parses dynamic map and nested maps without TypeError', () {
      final Map<dynamic, dynamic> rawDynamic = <dynamic, dynamic>{
        'data': <dynamic, dynamic>{
          'id': 15,
          'name': 'Alex Agent',
          'team': <dynamic, dynamic>{
            'id': 3,
            'team_code': 'TEAM_ALPHA',
            'team_name': 'Alpha Sales',
          },
        },
        'has_team_data_access': true,
        'permissions': <dynamic, dynamic>{
          'orders.view': true,
          'orders.create': false,
        },
      };

      // Wrap in Map<String, dynamic> at top level
      final json = rawDynamic.map((k, v) => MapEntry(k.toString(), v));
      final me = MeResponse.fromJson(json);

      expect(me.data.id, 15);
      expect(me.data.name, 'Alex Agent');
      expect(me.data.team?.teamCode, 'TEAM_ALPHA');
      expect(me.hasTeamDataAccess, true);
      expect(me.canViewOrders(), true);
      expect(me.canCreateOrders(), false);
    });

    test('Dio uri resolution check', () {
      final req = RequestOptions(
        baseUrl: 'https://leadx.cloudaspiresolutions.in/api/v1',
        path: '/employee/login',
      );
      expect(req.uri.toString(), 'https://leadx.cloudaspiresolutions.in/api/v1/employee/login');
    });
  });
}
