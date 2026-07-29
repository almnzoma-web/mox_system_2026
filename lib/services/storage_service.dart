import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  // القائمة المركزية للمنظومة
  static List<UserModel> registeredUsers = [];

  // علامة لتتبع ما إذا تم تحميل البيانات مسبقاً في الجلسة الحالية
  static bool _isLoaded = false;

  // تعريف المدير ببياناته السيادية
  static final UserModel adminUser = UserModel(
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
        _isLoaded = true;
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
        _isLoaded = true;
        await saveUsersList();
        debugPrint(
          "🏛️ [Storage] السجل كان فارغاً، تم تثبيت المدير كأول إدخال.",
        );
      }
    } catch (e) {
      debugPrint("❌ [Storage] خطأ فادح أثناء تحميل السجل: $e");
      registeredUsers = [adminUser];
      _isLoaded = true;
    }
  }

  // دالة ضمان التحميل الفوري (تمنع قراءة قائمة فارغة أبداً)
  static Future<void> ensureLoaded() async {
    if (!_isLoaded || registeredUsers.isEmpty) {
      await loadUsers();
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
      _isLoaded = true;
      debugPrint("✅ [Storage] تم حفظ السجل الكامل للعملاء في الخزينة بنجاح.");
    } catch (e) {
      debugPrint("❌ [Storage] خطأ أثناء حفظ السجل في الخزينة: $e");
    }
  }

  // دالة إضافة عميل جديد وتثبيته فوراً بالذاكرة الدائمة وعدم مسحه
  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded(); // ضمان تحميل القائمة الحقيقية أولاً

    int index = registeredUsers.indexWhere(
      (u) =>
          u.phone == newUser.phone ||
          (newUser.moxId != "لم يحدد" && u.moxId == newUser.moxId),
    );

    if (index != -1) {
      registeredUsers[index] = newUser;
      debugPrint("🔄 [Storage] العميل موجود مسبقاً، تم تحديث بياناته بنجاح.");
    } else {
      registeredUsers.add(newUser);
      debugPrint(
        "➕ [Storage] تم إضافة العميل الجديد ${newUser.name} وحفظه للأبد.",
      );
    }

    await saveUsersList();
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String userJson = jsonEncode(user.toJson());
      await prefs.setString(userKey, userJson);

      // استدعاء دالة الإضافة والحفظ المركزية
      await addUser(user);

      debugPrint(
        "🏛️ [Storage] نجاح: تم حفظ العميل النشط ${user.name} في الخزينة.",
      );
    } catch (e) {
      debugPrint("❌ [Storage] خطأ فادح في الحفظ: $e");
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(userKey);

      if (userJson == null) {
        debugPrint("⚠️ [Storage] تنبيه: الخزينة النشطة فارغة.");
        return null;
      }

      final user = UserModel.fromJson(jsonDecode(userJson));
      debugPrint("✅ [Storage] نجاح: تم استرجاع العميل النشط ${user.name}.");
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
      debugPrint("🧹 [Storage] تم إخلاء الخزينة النشطة بنجاح.");
    } catch (e) {
      debugPrint("❌ [Storage] خطأ أثناء الإخلاء: $e");
    }
  }

  static Future<Object?> getClientsData() async {
    await ensureLoaded();
    return registeredUsers.map((u) => u.toJson()).toList();
  }

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {
    registeredUsers = clientsData.map((e) => UserModel.fromJson(e)).toList();
    _isLoaded = true;
    await saveUsersList();
  }

  // دالة التحقق من الدخول (مع ضمان التحميل التلقائي)
  static Future<UserModel?> authenticateAsync(
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

  // دالة التحقق التزامن القديمة (محمية بالتأكد من تحميل القائمة إن أمكن)
  static UserModel? authenticate(String input, String password, bool isMoxId) {
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

  // الدوال السيادية الإضافية لتشغيل السوق المفتوح والروابط الخارجية عبر الـ moxId
  static Future<UserModel?> getUserByMoxId(String moxId) async {
    try {
      await ensureLoaded();
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
