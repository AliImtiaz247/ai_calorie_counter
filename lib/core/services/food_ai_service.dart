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

  /// Get User's Daily Scan Usage (5 scans/day limit metadata)
  Future<ScanUsage> getScanUsage() async {
    try {
      final res = await _apiClient.get("/api/scan-usage");
      if (res is Map<String, dynamic>) {
        return ScanUsage.fromJson(res);
      }
      return ScanUsage(limit: 5, used: 0, remaining: 5);
    } catch (_) {
      return ScanUsage(limit: 5, used: 0, remaining: 5);
    }
  }

  /// Send image to backend for AI Analysis
  Future<Map<String, dynamic>> analyzeFood(File image) async {
    // Client-side image validation (size limit: max 10MB)
    if (!await image.exists()) {
      throw Exception("Selected image file does not exist.");
    }

    final fileSizeInBytes = await image.length();
    const maxSizeBytes = 10 * 1024 * 1024; // 10 MB
    if (fileSizeInBytes > maxSizeBytes) {
      throw Exception("Image file size exceeds maximum limit of 10 MB. Please choose a smaller image.");
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
