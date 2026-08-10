import 'dart:io';

import '../models/scan_usage.dart';
import 'api_client.dart';
import 'language_service.dart';

class ScanLimitException implements Exception {
  final ScanUsage scanUsage;
  final String message;
  final String code;
  final bool retryable;
  final String? resetAt;

  ScanLimitException({
    required this.scanUsage,
    required this.message,
    this.code = 'DAILY_SCAN_LIMIT_REACHED',
    this.retryable = false,
    this.resetAt,
  });

  @override
  String toString() => message;
}

class ScanInProgressException implements Exception {
  final String message;

  const ScanInProgressException({
    this.message =
        'A food scan is already being processed. Please wait for it to finish.',
  });

  @override
  String toString() => message;
}

class AiQuotaTemporarilyExhaustedException implements Exception {
  final String message;
  final bool retryable;

  const AiQuotaTemporarilyExhaustedException({
    this.message =
        'Calorix AI is temporarily unavailable because the AI service has reached its current quota. Please try again later.',
    this.retryable = true,
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

  /// Gets authoritative daily scan usage from the backend.
  ///
  /// Never creates a fake fallback such as 5/5 here. If the backend cannot
  /// answer, the error is propagated so the UI does not show false quota data.
  Future<ScanUsage> getScanUsage() async {
    final response = await _apiClient.get('/api/analyze-food/status');

    if (response is Map<String, dynamic>) {
      return ScanUsage.fromJson(response);
    }

    throw ApiException(
      statusCode: 500,
      message: 'Invalid scan usage response from server.',
    );
  }

  /// Sends the image to the Calorix backend.
  ///
  /// The backend is responsible for image optimization, Gemini quota
  /// management, the authoritative 4-scan daily limit, idempotency and the
  /// single-user in-flight scan lock.
  Future<Map<String, dynamic>> analyzeFood(File image) async {
    if (!await image.exists()) {
      throw Exception('Selected image file does not exist.');
    }

    final fileSizeInBytes = await image.length();
    const maxSizeBytes = 10 * 1024 * 1024;

    if (fileSizeInBytes > maxSizeBytes) {
      throw Exception(
        'Image file size exceeds maximum limit of 10 MB. Please choose a smaller image.',
      );
    }

    final activeLanguage = LanguageService.currentLanguageNotifier.value;
    final localDate = _getFormattedLocalDate();

    final responseData = await _apiClient.multipartPost(
      path: '/api/analyze-food',
      file: image,
      fileFieldName: 'image',
      fields: {
        'language': activeLanguage,
        'date': localDate,
      },
    );

    if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    throw ApiException(
      statusCode: 500,
      message: 'Unexpected server response format.',
    );
  }
}
