import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  // القائمة المركزية للمنظومة
  static List<UserModel> registeredUsers = [];

  // تعريف المدير ببياناته السيادية
  static final UserModel adminUser = UserModel(
    phone: "249123240711",
    password: "MOX1234567890MOX",
    name: "مدير النظام",
    address: "المركز الرئيسي",
    balance: 5000.0,
    gender: "ذكر",
    accountType: "إدارة",
    moxId: "MOX249-00010001",
    role: "admin",
    points: 0,
    guardianMoxId: "MOX249-00010001",
  );

  // دالة التحميل السيادية من الذاكرة الدائمة
  static Future<void> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      String? encodedData = prefs.getString(savedUsersKey);

      if (encodedData != null && encodedData.isNotEmpty) {
        List<dynamic> jsonList = json.decode(encodedData);
        registeredUsers = jsonList
            .map((item) => UserModel.fromJson(item))
            .toList();
        debugPrint(
          "🏛️ [Storage] تم تحميل ${registeredUsers.length} مواطن من السجل بنجاح.",
        );

        if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
          registeredUsers.insert(0, adminUser);
          await saveUsersList();
          debugPrint(
            "🏛️ [Storage] المدير لم يكن موجوداً، تم تثبيته في رأس السجل.",
          );
        }
      } else {
        registeredUsers = [adminUser];
        await saveUsersList();
        debugPrint(
          "🏛️ [Storage] السجل كان فارغاً، تم تثبيت المدير كأول إدخال.",
        );
      }
    } catch (e) {
      debugPrint("❌ [Storage] خطأ فادح أثناء تحميل السجل: $e");
      registeredUsers = [adminUser];
    }
  }

  // دالة حفظ القائمة الكاملة للسجل في الخزينة
  static Future<void> saveUsersList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> jsonList = registeredUsers
          .map((u) => u.toJson())
          .toList();
      await prefs.setString(savedUsersKey, json.encode(jsonList));
      debugPrint("✅ [Storage] تم حفظ السجل الكامل للعملاء في الخزينة بنجاح.");
    } catch (e) {
      debugPrint("❌ [Storage] خطأ أثناء حفظ السجل في الخزينة: $e");
    }
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String userJson = jsonEncode(user.toJson());
      await prefs.setString(userKey, userJson);

      // تحديث أو إضافة المستخدم في القائمة المركزية تلقائياً
      await loadUsers();
      int index = registeredUsers.indexWhere(
        (u) =>
            u.phone == user.phone ||
            (user.moxId != "لم يحدد" && u.moxId == user.moxId),
      );
      if (index != -1) {
        registeredUsers[index] = user;
      } else {
        registeredUsers.add(user);
      }
      await saveUsersList();

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
    await loadUsers();
    return registeredUsers.map((u) => u.toJson()).toList();
  }

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {
    registeredUsers = clientsData.map((e) => UserModel.fromJson(e)).toList();
    await saveUsersList();
  }

  // الدوال السيادية الإضافية لتشغيل السوق المفتوح والروابط الخارجية عبر الـ moxId
  static Future<UserModel?> getUserByMoxId(String moxId) async {
    try {
      if (registeredUsers.isEmpty) {
        await loadUsers();
      }
      return registeredUsers.firstWhere(
        (u) => u.moxId == moxId || u.guardianMoxId == moxId,
      );
    } catch (e) {
      debugPrint("❌ [Storage] لم يتم العثور على العميل بالـ moxId: $moxId");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getClientCards(String moxId) async {
    try {
      UserModel? user = await getUserByMoxId(moxId);
      if (user != null && user.myAssets.isNotEmpty) {
        return user.myAssets.map((asset) => asset.toJson()).toList();
      }
    } catch (e) {
      debugPrint("❌ [Storage] خطأ في جلب بطاقات العميل عبر الـ moxId: $e");
    }

    // البطاقة الافتراضية بالمسطرة في حال عدم وجود أصول سابقة
    return [
      {
        'title': 'بطاقة المتجر السيادي الفاخرة',
        'description': 'منتج معتمد ومتاح للطلب الفوري عبر السوق المفتوح.',
        'price': 0.0,
        'whatsapp': '249115855164',
        'facebook': '',
      },
    ];
  }
}
