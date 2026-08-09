import 'package:flutter/foundation.dart';

class ApiService {
  /// Production HTTPS Domain (Used automatically in kReleaseMode)
  static const String _prodBaseUrl = "https://api.calorix.app";

  /// Local Development Base URL (Used in kDebugMode)
  static const String _devBaseUrl = "http://192.168.10.6:3000";

  /// Environment-Aware Active Base URL
  static String get baseUrl {
    if (kReleaseMode) {
      return _prodBaseUrl;
    }
    return _devBaseUrl;
  }
}
