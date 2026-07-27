import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String productsUrl =
      "https://script.google.com/macros/s/AKfycbzTZUHq81giVdgyiWpUyabmw0cKVSMTx4QGFs_Jdhjy_lVqY5yOGdzmVZd0K45mwFhySw/exec";
  static const String clientsUrl =
      "https://script.google.com/macros/s/AKfycbxotHZfcqaNaoZBcswcur7T824OY6qCdct9YPqvCaOdx_0kidd-Zgft7jr_rig6Zs02/exec";

  static Future<List<dynamic>> fetchData(
    String sheetName, {
    bool isClient = false,
  }) async {
    try {
      final url = isClient ? clientsUrl : productsUrl;
      final uri = Uri.parse('$url?sheet=$sheetName');

      debugPrint("جاري الاتصال بـ: $uri");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // تنظيف الاستجابة قبل فك التشفير
        final String body = response.body.trim();
        if (body.isEmpty) return [];

        final dynamic decoded = json.decode(body);
        return decoded is List ? decoded : [];
      }
      return [];
    } catch (e) {
      debugPrint("خطأ في جلب بيانات $sheetName: $e");
      return [];
    }
  }
}
