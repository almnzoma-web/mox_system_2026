import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart'; // ربط الجسر بالخزينة الهجينة والسحابية

// القائمة المركزية للمنظومة
List<UserModel> registeredUsers = [];

// تعريف المدير ببياناته السيادية
final UserModel adminUser = StorageService.adminUser;

// دالة التحميل السيادية (تعتمد على الخزينة الهجينة لضمان التزامن مع شيت قوقل)
Future<void> loadUsers() async {
  try {
    await StorageService.loadUsers();
    registeredUsers = StorageService.registeredUsers;
    debugPrint(
      "🏛️ [Data Bridge] تم مزامنة وتحميل ${registeredUsers.length} مواطن بنجاح.",
    );
  } catch (e) {
    debugPrint("❌ [Data Bridge] خطأ فادح أثناء تحميل السجل: $e");
    // العودة للاحتياطي المحلي الفوري عند الأزمات
    final prefs = await SharedPreferences.getInstance();
    String? encodedData = prefs.getString('saved_users');
    if (encodedData != null && encodedData.isNotEmpty) {
      List<dynamic> jsonList = json.decode(encodedData);
      registeredUsers = jsonList
          .map((item) => UserModel.fromJson(item))
          .toList();
    } else {
      registeredUsers = [adminUser];
    }
  }
}

// دالة الحفظ الدائم في الخزينة المركزية والشيت معاً
Future<void> saveUsers() async {
  try {
    StorageService.registeredUsers = registeredUsers;
    await StorageService.saveUsersList();
    debugPrint("✅ [Data Bridge] تم حفظ السجل الكامل وتحديث الشيت بنجاح.");
  } catch (e) {
    debugPrint("❌ [Data Bridge] خطأ أثناء الحفظ في الخزينة: $e");
  }
}

// دالة إضافة عميل جديد وتثبيته فوراً محلياً وسحابياً
Future<void> addUser(UserModel newUser) async {
  await StorageService.addUser(newUser);
  registeredUsers = StorageService.registeredUsers;
}

// دالة التحقق من الدخول (مع دعم الفحص الهجين السريع)
UserModel? authenticate(String input, String password, bool isMoxId) {
  try {
    return registeredUsers.firstWhere(
      (u) =>
          (isMoxId ? u.moxId == input : u.phone == input) &&
          u.password == password,
    );
  } catch (e) {
    return null;
  }
}
