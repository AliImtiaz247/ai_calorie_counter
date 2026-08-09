import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_food_result.dart';
import 'api_service.dart';

class AIFoodService {
  Future<AIFoodResult> analyzeFood(File image) async {
    final uri = Uri.parse("${ApiService.baseUrl}/api/analyze-food");

    final request = http.MultipartRequest("POST", uri);

    request.files.add(await http.MultipartFile.fromPath("image", image.path));

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("Server Error (${response.statusCode})");
    }

    final responseBody = await response.stream.bytesToString();

    final json = jsonDecode(responseBody);

    if (json["success"] != true) {
      throw Exception(json["error"] ?? "Unknown Error");
    }

    return AIFoodResult.fromJson(json["data"]);
  }
}
