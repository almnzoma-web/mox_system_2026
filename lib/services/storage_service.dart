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

  // الدوال السيادية الإضافية المطلوبة لتشغيل السوق المفتوح والروابط الخارجية
  static Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(userKey);
      if (userJson != null) {
        final user = UserModel.fromJson(jsonDecode(userJson));
        if (user.phone == phone) {
          return user;
        }
      }
      // إرجاع مستخدم افتراضي بالهاتف المستهدف إذا طابق الشروط
      return UserModel(
        name: "العميل السيادي",
        phone: phone,
        address: "المتجر الرقمي المفتوح",
        moxId: "MOX-STORE-2026",
        password: "",
        balance: 0.0,
        gender: "غير محدد",
        accountType: "client",
      );
    } catch (e) {
      debugPrint("❌ [Storage] خطأ في جلب العميل بالهاتف: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getClientCards(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cardsJson = prefs.getString('client_cards_$phone');
      if (cardsJson != null) {
        List<dynamic> decoded = jsonDecode(cardsJson);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("❌ [Storage] خطأ في جلب بطاقات العميل: $e");
    }

    // البطاقة الافتراضية بالمسطرة في حال عدم وجود مخزن سابق
    return [
      {
        'title': 'بطاقة المتجر السيادي الفاخرة',
        'description': 'منتج معتمد ومتاح للطلب الفوري عبر السوق المفتوح.',
        'price': 0.0,
        'whatsapp': phone,
        'facebook': '',
      },
    ];
  }
}
