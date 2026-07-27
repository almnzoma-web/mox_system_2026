import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String userJson = jsonEncode(user.toJson());
      await prefs.setString(userKey, userJson);
      debugPrint("🏛️ [Storage] نجاح: تم حفظ العميل ${user.name} في الخزينة.");
    } catch (e) {
      debugPrint("❌ [Storage] خطأ فادح في الحفظ: $e");
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(userKey);

      if (userJson == null) {
        debugPrint("⚠️ [Storage] تنبيه: الخزينة فارغة.");
        return null;
      }

      final user = UserModel.fromJson(jsonDecode(userJson));
      debugPrint("✅ [Storage] نجاح: تم استرجاع العميل ${user.name}.");
      return user;
    } catch (e) {
      debugPrint("❌ [Storage] خطأ فادح في الاسترجاع: $e");
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(userKey);
      debugPrint("🧹 [Storage] تم إخلاء الخزينة بنجاح.");
    } catch (e) {
      debugPrint("❌ [Storage] خطأ أثناء الإخلاء: $e");
    }
  }

  static Future<Object?> getClientsData() async {
    return null;
  }

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {}
}
