import 'dart:io';

import '../models/scan_usage.dart';
import 'api_client.dart';
import 'language_service.dart';

class ScanLimitException implements Exception {
  final ScanUsage scanUsage;
  final String message;

  ScanLimitException({
    required this.scanUsage,
    required this.message,
  });

  @override
  String toString() => message;
}

class FoodAIService {
  final ApiClient _apiClient = ApiClient.instance;

  String _getFormattedLocalDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Get the user's authoritative daily scan usage from the backend.
  ///
  /// The backend exposes this at /api/analyze-food/status. Do not silently
  /// convert a server/authentication failure into "5 scans remaining", because
  /// that makes the UI display stale usage and hides real API problems.
  Future<ScanUsage> getScanUsage() async {
    final res = await _apiClient.get("/api/analyze-food/status");

    if (res is Map<String, dynamic>) {
      return ScanUsage.fromJson(res);
    }

    throw ApiException(
      statusCode: 500,
      message: "Invalid scan usage response from server.",
    );
  }

  /// Send image to backend for AI Analysis
  Future<Map<String, dynamic>> analyzeFood(File image) async {
    if (!await image.exists()) {
      throw Exception("Selected image file does not exist.");
    }

    final fileSizeInBytes = await image.length();
    const maxSizeBytes = 10 * 1024 * 1024;
    if (fileSizeInBytes > maxSizeBytes) {
      throw Exception(
        "Image file size exceeds maximum limit of 10 MB. Please choose a smaller image.",
      );
    }

    final activeLanguage = LanguageService.currentLanguageNotifier.value;
    final localDate = _getFormattedLocalDate();

    final responseData = await _apiClient.multipartPost(
      path: "/api/analyze-food",
      file: image,
      fileFieldName: "image",
      fields: {
        "language": activeLanguage,
        "date": localDate,
      },
    );

    if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    throw Exception("Unexpected server response format.");
  }
}
