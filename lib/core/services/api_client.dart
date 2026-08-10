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
    bool forceRefresh = false,
  }) async {
    final idToken = await _authService.getIdToken(forceRefresh: forceRefresh);
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

  /// Centralized GET Request Handler with single 401 token-refresh retry
  Future<dynamic> get(String path, {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");
    var headers = await _getHeaders(forceRefresh: false);

    try {
      var response = await http.get(uri, headers: headers).timeout(timeout);

      // Single retry attempt on 401 by force-refreshing Firebase ID token
      if (response.statusCode == 401 && _authService.currentUser != null) {
        debugPrint("[ApiClient] 401 received on GET $path. Force-refreshing Firebase ID token and retrying...");
        headers = await _getHeaders(forceRefresh: true);
        response = await http.get(uri, headers: headers).timeout(timeout);
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(statusCode: 408, message: "Network request timed out. Please try again.");
    } on SocketException {
      throw ApiException(statusCode: 503, message: "Unable to connect to server. Check your internet connection.");
    } catch (e) {
      if (e is ApiException || e is ScanLimitException) rethrow;
      throw ApiException(statusCode: 500, message: "An unexpected error occurred.");
    }
  }

  /// Centralized Multipart POST Request Handler (Food AI Analysis) with 401 token-refresh retry
  Future<dynamic> multipartPost({
    required String path,
    required File file,
    required String fileFieldName,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");
    var headers = await _getHeaders(forceRefresh: false);

    Future<http.Response> sendRequest(Map<String, String> hdrs) async {
      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll(hdrs);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(await http.MultipartFile.fromPath(fileFieldName, file.path));

      final streamedResponse = await request.send().timeout(timeout);
      return await http.Response.fromStream(streamedResponse);
    }

    try {
      var response = await sendRequest(headers);

      // Single retry attempt on 401 by force-refreshing Firebase ID token
      if (response.statusCode == 401 && _authService.currentUser != null) {
        debugPrint("[ApiClient] 401 received on POST $path. Force-refreshing Firebase ID token and retrying...");
        headers = await _getHeaders(forceRefresh: true);
        response = await sendRequest(headers);
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(statusCode: 408, message: "Image processing timed out. Please try again.");
    } on SocketException {
      throw ApiException(statusCode: 503, message: "Unable to connect to server. Check internet connection.");
    } catch (e) {
      if (e is ApiException || e is ScanLimitException) rethrow;
      throw ApiException(statusCode: 500, message: "An error occurred while uploading image.");
    }
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

    // Handle 429 Daily Limit Reached (Must take precedence over generic errors)
    if (response.statusCode == 429 || (jsonBody is Map && jsonBody["error"] == "daily_limit_reached")) {
      final usage = ScanUsage(
        limit: jsonBody is Map ? (jsonBody["limit"] ?? 5) : 5,
        used: jsonBody is Map ? (jsonBody["used"] ?? 5) : 5,
        remaining: jsonBody is Map ? (jsonBody["remaining"] ?? 0) : 0,
        resetAt: jsonBody is Map ? jsonBody["resetAt"] : null,
      );
      throw ScanLimitException(
        scanUsage: usage,
        message: jsonBody is Map
            ? (jsonBody["message"] ?? "Daily scan limit reached (5/5). Scans reset at 12:00 AM.")
            : "Daily scan limit reached.",
      );
    }

    // Handle 401 Unauthorized (ONLY if 401 persists after ID token force-refresh)
    if (response.statusCode == 401) {
      final user = _authService.currentUser;
      if (user == null) {
        _authService.logout();
        throw ApiException(
          statusCode: 401,
          message: "Your session has expired. Please log in again.",
        );
      } else {
        throw ApiException(
          statusCode: 401,
          message: jsonBody is Map ? (jsonBody["message"] ?? "Authentication error. Please try again.") : "Authentication error. Please try again.",
        );
      }
    }

    // Handle 400 Bad Request
    if (response.statusCode == 400) {
      throw ApiException(
        statusCode: 400,
        message: jsonBody is Map ? (jsonBody["message"] ?? jsonBody["error"] ?? "Invalid request.") : "Invalid request.",
      );
    }

    // Handle 403 Forbidden
    if (response.statusCode == 403) {
      throw ApiException(
        statusCode: 403,
        message: jsonBody is Map ? (jsonBody["message"] ?? "Access denied.") : "Access denied.",
      );
    }

    // Server / Gemini Errors (500, 502, 503)
    final msg = (jsonBody is Map)
        ? (jsonBody["message"] ?? jsonBody["error"] ?? "Server error (${response.statusCode})")
        : "Server error (${response.statusCode})";

    throw ApiException(statusCode: response.statusCode, message: msg.toString());
  }
}
