import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/scan_usage.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'food_ai_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final bool retryable;

  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.retryable = false,
  });

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  factory ApiClient() => instance;

  final AuthService _authService = AuthService();

  String _getFormattedLocalDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<Map<String, String>> _getHeaders({
    Map<String, String>? extraHeaders,
    bool forceRefresh = false,
  }) async {
    final idToken = await _authService.getIdToken(forceRefresh: forceRefresh);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-date': _getFormattedLocalDate(),
    };

    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Centralized GET handler with exactly one Firebase token refresh retry.
  Future<dynamic> get(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    var headers = await _getHeaders();

    try {
      var response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 401 && _authService.currentUser != null) {
        debugPrint(
          '[ApiClient] 401 on GET $path. Refreshing Firebase ID token once.',
        );
        headers = await _getHeaders(forceRefresh: true);
        response = await http.get(uri, headers: headers).timeout(timeout);
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Network request timed out. Please try again.',
        retryable: true,
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: 'Unable to connect to server. Check your internet connection.',
        retryable: true,
      );
    } catch (e) {
      if (e is ApiException ||
          e is ScanLimitException ||
          e is ScanInProgressException ||
          e is AiQuotaTemporarilyExhaustedException) {
        rethrow;
      }

      throw ApiException(
        statusCode: 500,
        message: 'An unexpected error occurred.',
      );
    }
  }

  /// Multipart food-analysis request.
  ///
  /// There is deliberately no automatic retry for 429/503 AI responses here.
  /// Gemini quota errors must not cause repeated paid/free-tier requests.
  /// The backend owns transient Gemini retry/backoff and quota monitoring.
  Future<dynamic> multipartPost({
    required String path,
    required File file,
    required String fileFieldName,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    var headers = await _getHeaders();

    Future<http.Response> sendRequest(Map<String, String> requestHeaders) async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(requestHeaders);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(
        await http.MultipartFile.fromPath(fileFieldName, file.path),
      );

      final streamedResponse = await request.send().timeout(timeout);
      return http.Response.fromStream(streamedResponse);
    }

    try {
      var response = await sendRequest(headers);

      // Only authentication gets an automatic retry. Do not retry AI quota,
      // rate-limit, conflict, or server responses from the scan endpoint.
      if (response.statusCode == 401 && _authService.currentUser != null) {
        debugPrint(
          '[ApiClient] 401 on POST $path. Refreshing Firebase ID token once.',
        );
        headers = await _getHeaders(forceRefresh: true);
        response = await sendRequest(headers);
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Image processing timed out. Please try again.',
        retryable: true,
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: 'Unable to connect to server. Check your internet connection.',
        retryable: true,
      );
    } catch (e) {
      if (e is ApiException ||
          e is ScanLimitException ||
          e is ScanInProgressException ||
          e is AiQuotaTemporarilyExhaustedException) {
        rethrow;
      }

      throw ApiException(
        statusCode: 500,
        message: 'An error occurred while uploading image.',
      );
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic jsonBody;

    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (jsonBody is Map<String, dynamic> && jsonBody['success'] == true) {
        final data = jsonBody['data'];

        // Preserve backend metadata such as remainingScans, dailyLimit,
        // quota and usage. The previous implementation returned only `data`,
        // which silently discarded those fields from successful scan replies.
        if (data is Map<String, dynamic>) {
          final merged = Map<String, dynamic>.from(data);

          for (final key in const [
            'scansToday',
            'remainingScans',
            'dailyLimit',
            'usage',
            'quota',
            'resetAt',
            'cached',
          ]) {
            if (jsonBody.containsKey(key)) {
              merged[key] = jsonBody[key];
            }
          }

          return merged;
        }

        return data ?? jsonBody;
      }

      return jsonBody;
    }

    final body = jsonBody is Map<String, dynamic> ? jsonBody : <String, dynamic>{};
    final errorCode = _readString(body['errorCode']) ??
        _readString(body['code']) ??
        _readString(body['error']);
    final message = _readString(body['message']) ??
        'Server error (${response.statusCode}).';

    // Authoritative user limit: 4 scans/day.
    if (response.statusCode == 429 &&
        (errorCode == 'DAILY_SCAN_LIMIT_REACHED' ||
            errorCode == 'daily_limit_reached')) {
      final usage = ScanUsage.fromJson(body);

      throw ScanLimitException(
        scanUsage: usage,
        message: message,
        code: errorCode ?? 'DAILY_SCAN_LIMIT_REACHED',
        resetAt: usage.resetAt,
      );
    }

    // Prevent duplicate simultaneous scans from one user.
    if (response.statusCode == 409 &&
        errorCode == 'SCAN_ALREADY_IN_PROGRESS') {
      throw const ScanInProgressException();
    }

    // Google/Gemini quota is different from the user's daily scan limit.
    // The backend deliberately returns this as 503 so the Flutter app can
    // display a temporary AI-service message without consuming another scan.
    if (errorCode == 'AI_QUOTA_TEMPORARILY_EXHAUSTED') {
      throw AiQuotaTemporarilyExhaustedException(
        message: message,
        retryable: body['retryable'] == true,
      );
    }

    if (response.statusCode == 401) {
      final user = _authService.currentUser;

      if (user == null) {
        _authService.logout();
        throw ApiException(
          statusCode: 401,
          code: errorCode,
          message: 'Your session has expired. Please log in again.',
        );
      }

      throw ApiException(
        statusCode: 401,
        code: errorCode,
        message: message,
      );
    }

    if (response.statusCode == 400) {
      throw ApiException(
        statusCode: 400,
        code: errorCode,
        message: message,
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        statusCode: 403,
        code: errorCode,
        message: message,
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: errorCode,
      message: message,
      retryable: body['retryable'] == true,
    );
  }

  String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
