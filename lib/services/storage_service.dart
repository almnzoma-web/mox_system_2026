import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
// ignore: unused_import
import '../models/marketing_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  static List<UserModel> registeredUsers = [];
  static bool _isLoaded = false;

  // رابط قاعدة بيانات قوقل السحابية (Google Apps Script)
  static const String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbycCPFDCesTBzuQWhlpeBiacAuOs9nNz-f65GvcbbDOQ8q-Y2sKR8T40VW6Lwr4AWyO/exec";

  static final UserModel adminUser = UserModel(
    phone: "249115855164",
    password: "MOX1234567890MOX",
    name: "مدير النظام",
    address: "المركز الرئيسي",
    balance: 5000.0,
    commission: 0.0,
    gender: "ذكر",
    accountType: "إدارة",
    moxId: "ID-005000",
    role: "admin",
    customWhatsApp: "249115855164",
    guardianMoxId: "",
    guardianMoxIdCustomer: "MOX249-00010001",
    points: 0,
    myAssets: [],
  );

  // تحميل البيانات مع مزامنة ذكية تمنع أي حذف لبيانات قوقل الدائمة
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

      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
        await saveUsersList();
      }

      _isLoaded = true;
      // سحب التحديثات الدائمة من قاعدة بيانات قوقل في الخلفية
      _syncFromCloudInBackground();
    } catch (e) {
      debugPrint("❌ [Hybrid Local] خطأ في التحميل المحلي: $e");
      registeredUsers = [adminUser];
      _isLoaded = true;
    }
  }

  // المزامنة الدائمة مع قوقل لضمان بقاء كافة سجلات العملاء للأبد دون حذف
  static Future<void> _syncFromCloudInBackground() async {
    try {
      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> cloudList = json.decode(response.body);
        if (cloudList.isNotEmpty) {
          List<UserModel> cloudUsers = cloudList.map((item) {
            final mapItem = Map<String, dynamic>.from(item);
            // التأكد من جلب الـ moxId بكل أشكاله المحتملة في قوقل لمنع فراغه
            if ((mapItem['moxId'] == null ||
                    mapItem['moxId'].toString().trim().isEmpty) &&
                mapItem['MOXID'] != null) {
              mapItem['moxId'] = mapItem['MOXID'];
            }
            return UserModel.fromJson(mapItem);
          }).toList();

          // دمج ذكي يحافظ على كل عميل جديد وقائم في قوقل دون حذف أي سجل وبحماية الـ moxId
          for (var cloudUser in cloudUsers) {
            if (cloudUser.moxId.isEmpty || cloudUser.moxId == "null") continue;

            int index = registeredUsers.indexWhere(
              (u) => u.phone == cloudUser.phone || u.moxId == cloudUser.moxId,
            );
            if (index != -1) {
              if (cloudUser.moxId.isNotEmpty && cloudUser.moxId != "null") {
                registeredUsers[index] = cloudUser;
              }
            } else {
              registeredUsers.add(cloudUser);
            }
          }

          if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
            registeredUsers.insert(0, adminUser);
          }

          await saveUsersList();
        }
      }
    } catch (_) {}
  }

  static Future<void> ensureLoaded() async {
    if (!_isLoaded || registeredUsers.isEmpty) {
      await loadUsers();
    }
  }

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

  // إضافة عميل جديد وترحيله فوراً إلى قاعدة بيانات قوقل مع حماية صارمة للـ moxId
  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    if (newUser.moxId.trim().isEmpty || newUser.moxId == "null") {
      debugPrint("❌ [Cloud Sync] محاولة حفظ عميل بدون MoxId تم رفضها!");
      return;
    }

    int index = registeredUsers.indexWhere(
      (u) =>
          u.phone == newUser.phone ||
          (newUser.moxId != "ID-000001" && u.moxId == newUser.moxId),
    );

    if (index != -1) {
      registeredUsers[index] = newUser;
    } else {
      registeredUsers.add(newUser);
    }

    await saveUsersList();

    try {
      String encodedAssets = "[]";
      try {
        encodedAssets = json.encode(
          newUser.myAssets.map((a) {
            if (a is Map) return a;
            return a.toJson();
          }).toList(),
        );
      } catch (_) {}

      final queryParameters = {
        'action': 'save',
        'phone': newUser.phone,
        'password': newUser.password,
        'name': newUser.name,
        'address': newUser.address,
        'balance': newUser.balance.toString(),
        'commission': newUser.commission.toString(),
        'gender': newUser.gender,
        'accountType': newUser.accountType,
        'moxId': newUser.moxId,
        'role': newUser.role,
        'customWhatsApp': newUser.customWhatsApp ?? '',
        'guardianMoxId': newUser.guardianMoxId ?? '',
        'guardianMoxIdCustomer': newUser.guardianMoxIdCustomer ?? '',
        'points': newUser.points.toString(),
        'myAssets': encodedAssets,
      };

      final uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: queryParameters);
      await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("❌ [Cloud Sync] خطأ في رفع العميل لقوقل: $e");
    }
  }

  // التحديث الجزئي مع الحفاظ التام على السجلات في قوقل
  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (user.moxId.trim().isEmpty) return;

    int index = registeredUsers.indexWhere(
      (u) => u.moxId == user.moxId || u.phone == user.phone,
    );
    if (index != -1) {
      registeredUsers[index] = user;
      await saveUsersList();
    }

    try {
      String encodedAssets = "[]";
      try {
        encodedAssets = json.encode(
          user.myAssets.map((a) {
            if (a is Map) return a;
            return a.toJson();
          }).toList(),
        );
      } catch (_) {}

      final queryParameters = {
        'action': 'save',
        'phone': user.phone,
        'password': user.password,
        'name': user.name,
        'address': user.address,
        'balance': user.balance.toString(),
        'commission': user.commission.toString(),
        'gender': user.gender,
        'accountType': user.accountType,
        'moxId': user.moxId,
        'role': user.role,
        'customWhatsApp': user.customWhatsApp ?? '',
        'guardianMoxId': user.guardianMoxId ?? '',
        'guardianMoxIdCustomer': user.guardianMoxIdCustomer ?? '',
        'points': user.points.toString(),
        'myAssets': encodedAssets,
      };

      final uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: queryParameters);
      await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint("❌ [Cloud Sync] خطأ في تحديث البيانات بقوقل: $e");
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

  // تنظيف الذاكرة المؤقتة النشطة فقط عند تسجيل الخروج مع بقاء البيانات في قوقل سليمة تماماً
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

  // 🛡️ [تحديث حاسم للقدلة]: التحقق من العميل محلياً، وإذا لم يوجد بسبب التحديث، يتم استدعاؤه فوراً من سحابة قوقل وحفظه محلياً
  static Future<UserModel?> authenticateAsync(
    String input,
    String password,
    bool isMoxId,
  ) async {
    await ensureLoaded();

    // 1. المحاولة الأولى: البحث داخل القائمة المحلية المحملة
    UserModel? foundUser;
    try {
      foundUser = registeredUsers.firstWhere(
        (u) =>
            (isMoxId ? u.moxId == input : u.phone == input) &&
            u.password == password,
      );
    } catch (_) {
      foundUser = null;
    }

    // 2. إذا لم يتم العثور عليه محلياً (مثلاً بسبب مسح الذاكرة بعد تحديث التطبيق)، نسحب المباشرة من قوقل (Cloud Fallback)
    if (foundUser == null) {
      try {
        debugPrint(
          "🌐 [Cloud Fallback] العميل غير موجود محلياً، جارٍ الاستعلام المباشر من سحابة قوقل...",
        );
        final response = await http
            .get(Uri.parse('$_scriptUrl?action=getAll'))
            .timeout(const Duration(seconds: 7));

        if (response.statusCode == 200) {
          List<dynamic> cloudList = json.decode(response.body);
          for (var item in cloudList) {
            final mapItem = Map<String, dynamic>.from(item);
            if ((mapItem['moxId'] == null ||
                    mapItem['moxId'].toString().trim().isEmpty) &&
                mapItem['MOXID'] != null) {
              mapItem['moxId'] = mapItem['MOXID'];
            }

            UserModel cloudUser = UserModel.fromJson(mapItem);

            // مطابقة المدخلات مع العميل القادم من السحابة
            bool matches = isMoxId
                ? cloudUser.moxId == input
                : cloudUser.phone == input;

            if (matches && cloudUser.password == password) {
              foundUser = cloudUser;
              // حقنه فوراً في الذاكرة المحلية وقائمة المسجلين لتثبيته للأبد
              if (!registeredUsers.any((u) => u.moxId == foundUser!.moxId)) {
                registeredUsers.add(foundUser);
              } else {
                int idx = registeredUsers.indexWhere(
                  (u) => u.moxId == foundUser!.moxId,
                );
                if (idx != -1) registeredUsers[idx] = foundUser;
              }
              await saveUsersList();
              debugPrint(
                "✅ [Cloud Fallback] تم استدعاء العميل من قوقل وحفظه محلياً بنجاح.",
              );
              break;
            }
          }
        }
      } catch (e) {
        debugPrint(
          "❌ [Cloud Fallback Error] فشل جلب العميل الطارئ من قوقل: $e",
        );
      }
    }

    return foundUser;
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
        (u) =>
            u.moxId == moxId ||
            u.guardianMoxId == moxId ||
            u.guardianMoxIdCustomer == moxId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getClientCards(String moxId) async {
    try {
      UserModel? user = await getUserByMoxId(moxId);
      if (user != null && user.myAssets.isNotEmpty) {
        List<Map<String, dynamic>> formattedAssets = [];
        for (var asset in user.myAssets) {
          if (asset is Map<String, dynamic>) {
            formattedAssets.add(asset as Map<String, dynamic>);
          } else {
            try {
              final jsonMap = (asset as dynamic).toJson();
              if (jsonMap is Map<String, dynamic>) {
                formattedAssets.add(jsonMap);
              }
            } catch (_) {}
          }
        }
        return formattedAssets;
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
