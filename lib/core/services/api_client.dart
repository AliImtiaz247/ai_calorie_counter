import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/scan_usage.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'food_ai_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

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
    bool forceRefreshToken = false,
  }) async {
    final idToken = await _authService.getIdToken(
      forceRefresh: forceRefreshToken,
    );
    final headers = <String, String>{
      "Content-Type": "application/json",
      "x-user-date": _getFormattedLocalDate(),
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers["Authorization"] = "Bearer $idToken";
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");

    try {
      var headers = await _getHeaders();
      var response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode == 401 && _authService.currentUser != null) {
        headers = await _getHeaders(forceRefreshToken: true);
        response = await http.get(uri, headers: headers).timeout(timeout);
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: "Network request timed out. Please try again.",
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: "Unable to connect to server. Check your internet connection.",
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 500,
        message: "An unexpected error occurred.",
      );
    }
  }

  Future<dynamic> multipartPost({
    required String path,
    required File file,
    required String fileFieldName,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");

    try {
      var headers = await _getHeaders();
      var response = await _sendMultipartRequest(
        uri: uri,
        headers: headers,
        file: file,
        fileFieldName: fileFieldName,
        fields: fields,
        timeout: timeout,
      );

      // A Firebase ID token can expire while the app is open. Refresh it and
      // retry exactly once instead of logging the user out immediately.
      if (response.statusCode == 401 && _authService.currentUser != null) {
        headers = await _getHeaders(forceRefreshToken: true);
        response = await _sendMultipartRequest(
          uri: uri,
          headers: headers,
          file: file,
          fileFieldName: fileFieldName,
          fields: fields,
          timeout: timeout,
        );
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: "Image processing timed out. Please try again.",
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: "Unable to connect to server. Check internet connection.",
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 500,
        message: "An error occurred while uploading image.",
      );
    }
  }

  Future<http.Response> _sendMultipartRequest({
    required Uri uri,
    required Map<String, String> headers,
    required File file,
    required String fileFieldName,
    Map<String, String>? fields,
    required Duration timeout,
  }) async {
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      await http.MultipartFile.fromPath(fileFieldName, file.path),
    );

    final streamedResponse = await request.send().timeout(timeout);
    return http.Response.fromStream(streamedResponse);
  }

  dynamic _processResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode == 200) {
      if (jsonBody is Map<String, dynamic> && jsonBody["success"] == true) {
        return jsonBody["data"] ?? jsonBody;
      }
      return jsonBody;
    }

    // A 401 after the single token-refresh retry means the backend rejected
    // the refreshed Firebase token. Do not call signOut() here: Firebase
    // remains the source of truth and the user must not be logged out merely
    // because an API request failed.
    if (response.statusCode == 401) {
      throw ApiException(
        statusCode: 401,
        message: "Authentication with the server failed. Please try again.",
      );
    }

    if (response.statusCode == 429 ||
        (jsonBody is Map && jsonBody["error"] == "daily_limit_reached")) {
      final usage = ScanUsage(
        limit: jsonBody is Map ? (jsonBody["limit"] ?? 5) : 5,
        used: jsonBody is Map ? (jsonBody["used"] ?? 5) : 5,
        remaining: jsonBody is Map ? (jsonBody["remaining"] ?? 0) : 0,
        resetAt: jsonBody is Map ? jsonBody["resetAt"] : null,
      );
      throw ScanLimitException(
        scanUsage: usage,
        message: jsonBody is Map
            ? (jsonBody["message"] ??
                "Daily scan limit reached (5/5). Scans reset at 12:00 AM.")
            : "Daily scan limit reached.",
      );
    }

    if (response.statusCode == 403) {
      throw ApiException(
        statusCode: 403,
        message: jsonBody is Map
            ? (jsonBody["message"] ?? "Access denied.")
            : "Access denied.",
      );
    }

    final msg = (jsonBody is Map)
        ? (jsonBody["error"] ??
            jsonBody["message"] ??
            "Server error (${response.statusCode})")
        : "Server error (${response.statusCode})";

    throw ApiException(
      statusCode: response.statusCode,
      message: msg.toString(),
    );
  }
}
