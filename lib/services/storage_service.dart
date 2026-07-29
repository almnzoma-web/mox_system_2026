import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  static List<UserModel> registeredUsers = [];
  static bool _isLoaded = false;

  // رابط شيت قوقل السحابي الخاص بك
  static const String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbwwJkrdVEfCyOhdQvWO3rd0DlYZ_H7TyAd9hz5XkmxGV9yiBNBir89_4Y3Au2U2t10/exec";

  // تعريف المدير السيادي بكافة الحقول الشاملة (الواتساب، العمولات، الأصول، وغيرها)
  static final UserModel adminUser = UserModel(
    phone: "249115855164",
    password: "MOX1234567890MOX",
    name: "مدير النظام",
    address: "المركز الرئيسي",
    balance: 5000.0,
    commission: 0.0,
    gender: "ذكر",
    accountType: "إدارة",
    moxId: "MOX249-00010001",
    role: "admin",
    customWhatsApp: "249115855164",
    guardianMoxId: "MOX249-00010001",
    points: 0,
    myAssets: [],
  );

  // دالة التحميل المحلية الفورية (تفتح بسرعة البرق حتى لو انقطع الإنترنت)
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
      }

      // التأكد من وجود المدير السيادي دائماً
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
        await saveUsersList();
      }

      _isLoaded = true;
      debugPrint(
        "🏛️ [Hybrid Local] تم تحميل ${registeredUsers.length} مواطن محلياً.",
      );

      // مزامنة صامتة في الخلفية مع شيت قوقل
      _syncFromCloudInBackground();
    } catch (e) {
      debugPrint("❌ [Hybrid Local] خطأ في التحميل المحلي: $e");
      registeredUsers = [adminUser];
      _isLoaded = true;
    }
  }

  // مزامنة ذكية تعيد البيانات من الشيت للمحلية في الخلفية
  static Future<void> _syncFromCloudInBackground() async {
    try {
      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> cloudList = json.decode(response.body);
        if (cloudList.isNotEmpty) {
          List<UserModel> cloudUsers = cloudList
              .map(
                (item) => UserModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();

          // دمج وتحديث القائمة المحلية بأحدث بيانات الشيت
          for (var cloudUser in cloudUsers) {
            int index = registeredUsers.indexWhere(
              (u) => u.phone == cloudUser.phone || u.moxId == cloudUser.moxId,
            );
            if (index != -1) {
              registeredUsers[index] = cloudUser;
            } else {
              registeredUsers.add(cloudUser);
            }
          }

          if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
            registeredUsers.insert(0, adminUser);
          }

          await saveUsersList();
          debugPrint(
            "☁️ [Hybrid Sync] تمت المزامنة العكسية من الشيت إلى المحلية بنجاح.",
          );
        }
      }
    } catch (_) {
      // الإنترنت ضعيف أو مقطوع، التطبيق يعمل بكفاءة كاملة على المحلي
    }
  }

  static Future<void> ensureLoaded() async {
    if (!_isLoaded || registeredUsers.isEmpty) {
      await loadUsers();
    }
  }

  // دالة الحفظ المحلي مع إرسال التحديث للشيت في الخلفية
  static Future<void> saveUsersList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> jsonList = registeredUsers
          .map((u) => u.toJson())
          .toList();
      await prefs.setString(savedUsersKey, json.encode(jsonList));
      _isLoaded = true;
    } catch (e) {
      debugPrint("❌ [Hybrid Local] خطأ أثناء الحفظ المحلي: $e");
    }
  }

  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    int index = registeredUsers.indexWhere(
      (u) =>
          u.phone == newUser.phone ||
          (newUser.moxId != "لم يحدد" && u.moxId == newUser.moxId),
    );

    if (index != -1) {
      registeredUsers[index] = newUser;
    } else {
      registeredUsers.add(newUser);
    }

    await saveUsersList();

    // رفع التحديث للشيت فوراً في الخلفية مع كامل الحقول
    try {
      await http
          .post(
            Uri.parse(_scriptUrl),
            body: json.encode(newUser.toJson()),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint("❌ [Cloud Sync] خطأ في رفع العميل للشيت: $e");
    }
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String userJson = jsonEncode(user.toJson());
      await prefs.setString(userKey, userJson);

      await addUser(user);
    } catch (e) {
      debugPrint("❌ [Hybrid Local] خطأ في حفظ العميل النشط: $e");
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(userKey);
      if (userJson == null) return null;
      return UserModel.fromJson(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(userKey);
    } catch (_) {}
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

  // تسجيل دخول فوري بالمعلومات المحلية
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

  static Future<UserModel?> getUserByMoxId(String moxId) async {
    try {
      await ensureLoaded();
      return registeredUsers.firstWhere(
        (u) => u.moxId == moxId || u.guardianMoxId == moxId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getClientCards(String moxId) async {
    try {
      UserModel? user = await getUserByMoxId(moxId);
      if (user != null && user.myAssets.isNotEmpty) {
        return user.myAssets.map((asset) => asset.toJson()).toList();
      }
    } catch (_) {}

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
