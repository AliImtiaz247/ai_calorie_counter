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

  Future<Map<String, String>> _getHeaders({Map<String, String>? extraHeaders}) async {
    final idToken = await _authService.getIdToken();
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

  /// Centralized GET Request Handler
  Future<dynamic> get(String path, {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");
    final headers = await _getHeaders();

    try {
      final response = await http.get(uri, headers: headers).timeout(timeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(statusCode: 408, message: "Network request timed out. Please try again.");
    } on SocketException {
      throw ApiException(statusCode: 503, message: "Unable to connect to server. Check your internet connection.");
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 500, message: "An unexpected error occurred.");
    }
  }

  /// Centralized Multipart POST Request Handler (Food AI Analysis)
  Future<dynamic> multipartPost({
    required String path,
    required File file,
    required String fileFieldName,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.parse("${ApiService.baseUrl}$path");
    final headers = await _getHeaders();

    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(await http.MultipartFile.fromPath(fileFieldName, file.path));

    try {
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(statusCode: 408, message: "Image processing timed out. Please try again.");
    } on SocketException {
      throw ApiException(statusCode: 503, message: "Unable to connect to server. Check internet connection.");
    } catch (e) {
      if (e is ApiException) rethrow;
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

    // Handle 401 Unauthorized
    if (response.statusCode == 401) {
      _authService.logout();
      throw ApiException(
        statusCode: 401,
        message: "Your session has expired. Please log in again.",
      );
    }

    // Handle 429 Daily Limit Reached
    if (response.statusCode == 429 || (jsonBody is Map && jsonBody["error"] == "daily_limit_reached")) {
      final usage = ScanUsage(
        limit: jsonBody is Map ? (jsonBody["limit"] ?? 5) : 5,
        used: jsonBody is Map ? (jsonBody["used"] ?? 5) : 5,
        remaining: jsonBody is Map ? (jsonBody["remaining"] ?? 0) : 0,
        resetAt: jsonBody is Map ? jsonBody["resetAt"] : null,
      );
      throw ScanLimitException(
        scanUsage: usage,
        message: jsonBody is Map ? (jsonBody["message"] ?? "Daily scan limit reached (5/5). Scans reset at 12:00 AM.") : "Daily scan limit reached.",
      );
    }

    // Handle 403 Forbidden
    if (response.statusCode == 403) {
      throw ApiException(
        statusCode: 403,
        message: jsonBody is Map ? (jsonBody["message"] ?? "Access denied.") : "Access denied.",
      );
    }

    // Server Errors (500, 502, 503)
    final msg = (jsonBody is Map)
        ? (jsonBody["error"] ?? jsonBody["message"] ?? "Server error (${response.statusCode})")
        : "Server error (${response.statusCode})";

    throw ApiException(statusCode: response.statusCode, message: msg.toString());
  }
}
