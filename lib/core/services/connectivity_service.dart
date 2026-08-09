import 'dart:io';

import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
    return false;
  }
}
