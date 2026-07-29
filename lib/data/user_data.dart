import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

// القائمة المركزية للمنظومة
List<UserModel> registeredUsers = [];

// علامة لتتبع حالة التحميل في الذاكرة الحية
bool _isLoaded = false;

// تعريف المدير ببياناته السيادية الموحدة
final UserModel adminUser = UserModel(
  phone: "249115855164",
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

// دالة التحميل السيادية من الذاكرة الدائمة (محصنة بالمسطرة)
Future<void> loadUsers() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    String? encodedData = prefs.getString('saved_users');

    if (encodedData != null && encodedData.isNotEmpty) {
      List<dynamic> jsonList = json.decode(encodedData);
      registeredUsers = jsonList
          .map((item) => UserModel.fromJson(item))
          .toList();
      _isLoaded = true;
      debugPrint(
        "🏛️ [Data] تم تحميل ${registeredUsers.length} مواطن من السجل بنجاح.",
      );

      // التأكد من وجود المدير في القائمة دون الإخلال بباقي المواطنين
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
        await saveUsers();
        debugPrint("🏛️ [Data] المدير لم يكن موجوداً، تم تثبيته في رأس السجل.");
      }
    } else {
      registeredUsers = [adminUser];
      _isLoaded = true;
      await saveUsers();
      debugPrint("🏛️ [Data] السجل كان فارغاً، تم تثبيت المدير كأول إدخال.");
    }
  } catch (e) {
    debugPrint("❌ [Data] خطأ فادح أثناء تحميل السجل: $e");
    registeredUsers = [adminUser];
    _isLoaded = true;
  }
}

// دالة ضمان التحميل الفوري المتوافقة مع StorageService
Future<void> ensureLoaded() async {
  if (!_isLoaded || registeredUsers.isEmpty) {
    await loadUsers();
  }
}

// دالة الحفظ الدائم في الخزينة المركزية
Future<void> saveUsers() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList = registeredUsers
        .map((u) => u.toJson())
        .toList();
    await prefs.setString('saved_users', json.encode(jsonList));
    _isLoaded = true;
    debugPrint("✅ [Data] تم حفظ السجل الكامل للعملاء في الخزينة بنجاح.");
  } catch (e) {
    debugPrint("❌ [Data] خطأ أثناء الحفظ في الخزينة: $e");
  }
}

// دالة توافقية بديلة لاسم saveUsersList
Future<void> saveUsersList() async {
  await saveUsers();
}

// دالة إضافة عميل جديد وتثبيته فوراً بالذاكرة الدائمة وعدم مسحه
Future<void> addUser(UserModel newUser) async {
  await ensureLoaded(); // التأكد من تحميل أحدث نسخة قبل التعديل

  int index = registeredUsers.indexWhere(
    (u) =>
        u.phone == newUser.phone ||
        (newUser.moxId != "لم يحدد" && u.moxId == newUser.moxId),
  );

  if (index != -1) {
    registeredUsers[index] = newUser;
    debugPrint("🔄 [Data] العميل موجود مسبقاً، تم تحديث بياناته بنجاح.");
  } else {
    registeredUsers.add(newUser);
    debugPrint("➕ [Data] تم إضافة العميل الجديد ${newUser.name} وحفظه للأبد.");
  }

  await saveUsers();
}

// دوال مساعدة للتوافق الشامل مع باقي الملفات والخدمات
Future<Object?> getClientsData() async {
  await ensureLoaded();
  return registeredUsers.map((u) => u.toJson()).toList();
}

Future<void> saveClientsData(List<Map<String, dynamic>> clientsData) async {
  registeredUsers = clientsData.map((e) => UserModel.fromJson(e)).toList();
  _isLoaded = true;
  await saveUsers();
}

// دالة التحقق من الدخول (غير المتزامنة)
Future<UserModel?> authenticateAsync(
  String input,
  String password,
  bool isMoxId,
) async {
  await ensureLoaded();
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

// دالة التحقق من الدخول (المتزامنة القديمة للتوافق)
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
