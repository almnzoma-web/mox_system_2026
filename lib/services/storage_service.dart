import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/marketing_card.dart';
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  static List<UserModel> registeredUsers = [];
  static bool _isLoaded = false;

  // ============================================================
  // GOOGLE APPS SCRIPT
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbycCPFDCesTBzuQWhlpeBiacAu9sNz-f65GvcbbDOQ8q-Y2sKR8T40VW6Lwr4AWyO/exec';

  // ============================================================
  // ADMIN
  // ============================================================

  static final UserModel adminUser = UserModel(
    phone: '249115855164',
    password: 'MOX1234567890MOX',
    name: 'مدير النظام',
    address: 'المركز الرئيسي',
    storeDescription: 'المركز الرئيسي لمنصة MOX الرقمية',
    balance: 5000.0,
    commission: 0.0,
    gender: 'ذكر',
    accountType: 'إدارة',
    moxId: 'ID-005000',
    role: 'admin',
    customWhatsApp: '249115855164',
    guardianMoxId: '',
    guardianMoxIdCustomer: 'MOX249-00010001',
    points: 0,
    myAssets: [],
  );

  // ============================================================
  // LOAD USERS
  // ============================================================

  static Future<void> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final String? encodedData = prefs.getString(savedUsersKey);

      if (encodedData != null && encodedData.isNotEmpty) {
        final dynamic decoded = jsonDecode(encodedData);

        if (decoded is List) {
          registeredUsers = decoded
              .map(
                (item) => UserModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
      }

      // ضمان وجود المدير
      final bool adminExists = registeredUsers.any(
        (u) => u.moxId == adminUser.moxId,
      );

      if (!adminExists) {
        registeredUsers.insert(0, adminUser);
        await saveUsersList();
      }

      _isLoaded = true;

      // المزامنة السحابية في الخلفية
      _syncFromCloudInBackground();
    } catch (e) {
      debugPrint('❌ [Storage] خطأ في التحميل المحلي: $e');

      registeredUsers = [adminUser];
      _isLoaded = true;
    }
  }

  // ============================================================
  // CLOUD SYNC
  // ============================================================

  static Future<void> _syncFromCloudInBackground() async {
    try {
      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List || decoded.isEmpty) {
        return;
      }

      final List<UserModel> cloudUsers = [];

      for (final item in decoded) {
        try {
          final mapItem = Map<String, dynamic>.from(item);

          // دعم moxId / MOXID
          if ((mapItem['moxId'] == null ||
                  mapItem['moxId'].toString().trim().isEmpty) &&
              mapItem['MOXID'] != null) {
            mapItem['moxId'] = mapItem['MOXID'];
          }

          final user = UserModel.fromJson(mapItem);

          if (user.moxId.trim().isNotEmpty &&
              user.moxId != 'null' &&
              user.moxId != 'لم يحدد') {
            cloudUsers.add(user);
          }
        } catch (e) {
          debugPrint('⚠️ [Cloud] تجاهل سجل غير صالح: $e');
        }
      }

      // دمج البيانات بدون حذف المستخدمين المحليين
      for (final cloudUser in cloudUsers) {
        final int index = registeredUsers.indexWhere(
          (localUser) =>
              localUser.phone == cloudUser.phone ||
              localUser.moxId == cloudUser.moxId,
        );

        if (index >= 0) {
          registeredUsers[index] = cloudUser;
        } else {
          registeredUsers.add(cloudUser);
        }
      }

      // ضمان المدير
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
      }

      await saveUsersList();
    } catch (e) {
      debugPrint('⚠️ [Cloud Sync] فشل المزامنة الخلفية: $e');
    }
  }

  // ============================================================
  // ENSURE LOADED
  // ============================================================

  static Future<void> ensureLoaded() async {
    if (!_isLoaded || registeredUsers.isEmpty) {
      await loadUsers();
    }
  }

  // ============================================================
  // SAVE LOCAL USERS
  // ============================================================

  static Future<void> saveUsersList() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> jsonList = registeredUsers
          .map((user) => user.toJson())
          .toList();

      await prefs.setString(savedUsersKey, jsonEncode(jsonList));

      _isLoaded = true;
    } catch (e) {
      debugPrint('❌ [Storage] خطأ في الحفظ المحلي: $e');
    }
  }

  // ============================================================
  // ASSET ENCODER
  // ============================================================

  static String _encodeAssets(List<MarketingCard> assets) {
    try {
      return jsonEncode(assets.map((asset) => asset.toJson()).toList());
    } catch (e) {
      debugPrint('⚠️ [Assets] خطأ في تحويل الأصول: $e');
      return '[]';
    }
  }

  // ============================================================
  // CLOUD SAVE
  // ============================================================

  static Future<void> _saveToCloud(UserModel user) async {
    try {
      final Map<String, String> queryParameters = {
        'action': 'save',
        'phone': user.phone,
        'password': user.password,
        'name': user.name,
        'address': user.address,
        'storeDescription': user.storeDescription,
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
        'myAssets': _encodeAssets(user.myAssets),
      };

      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: queryParameters);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [Cloud] استجابة غير ناجحة: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [Cloud] خطأ في الحفظ السحابي: $e');
    }
  }

  // ============================================================
  // ADD USER
  // ============================================================

  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    if (newUser.moxId.trim().isEmpty ||
        newUser.moxId == 'null' ||
        newUser.moxId == 'لم يحدد') {
      debugPrint('❌ [Cloud] محاولة إضافة مستخدم بدون MoxId مرفوضة.');
      return;
    }

    final int index = registeredUsers.indexWhere(
      (user) =>
          user.phone == newUser.phone ||
          (newUser.moxId != 'ID-000001' && user.moxId == newUser.moxId),
    );

    if (index >= 0) {
      registeredUsers[index] = newUser;
    } else {
      registeredUsers.add(newUser);
    }

    await saveUsersList();

    await _saveToCloud(newUser);
  }

  // ============================================================
  // PARTIAL UPDATE
  // ============================================================

  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (user.moxId.trim().isEmpty) {
      return;
    }

    final int index = registeredUsers.indexWhere(
      (existing) =>
          existing.moxId == user.moxId || existing.phone == user.phone,
    );

    if (index >= 0) {
      registeredUsers[index] = user;
      await saveUsersList();
    }

    // تحديث الجلسة الحالية
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? currentUserJson = prefs.getString(userKey);

      if (currentUserJson != null && currentUserJson.isNotEmpty) {
        final UserModel activeUser = UserModel.fromJson(
          jsonDecode(currentUserJson),
        );

        if (activeUser.moxId == user.moxId || activeUser.phone == user.phone) {
          await prefs.setString(userKey, jsonEncode(user.toJson()));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Session] خطأ في تحديث الجلسة: $e');
    }

    // التحديث السحابي
    await _saveToCloud(user);
  }

  // ============================================================
  // SAVE ACTIVE USER
  // ============================================================

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(user.toJson()));

      await addUser(user);
    } catch (e) {
      debugPrint('❌ [Storage] خطأ في حفظ المستخدم النشط: $e');
    }
  }

  // ============================================================
  // GET ACTIVE USER
  // ============================================================

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? userJson = prefs.getString(userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      return UserModel.fromJson(jsonDecode(userJson));
    } catch (e) {
      debugPrint('⚠️ [Storage] تعذر قراءة المستخدم النشط: $e');
      return null;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(userKey);
    } catch (e) {
      debugPrint('⚠️ [Storage] خطأ أثناء تسجيل الخروج: $e');
    }
  }

  // ============================================================
  // CLIENTS DATA
  // ============================================================

  static Future<Object?> getClientsData() async {
    await ensureLoaded();

    return registeredUsers.map((user) => user.toJson()).toList();
  }

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {
    try {
      registeredUsers = clientsData
          .map((item) => UserModel.fromJson(item))
          .toList();

      // ضمان المدير
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
      }

      _isLoaded = true;

      await saveUsersList();

      // مزامنة كل السجلات مع السحابة
      for (final user in registeredUsers) {
        if (user.moxId != adminUser.moxId) {
          await _saveToCloud(user);
        }
      }
    } catch (e) {
      debugPrint('❌ [Clients] خطأ في حفظ بيانات العملاء: $e');
    }
  }

  // ============================================================
  // AUTHENTICATE LOCAL
  // ============================================================

  static UserModel? authenticate(String input, String password, bool isMoxId) {
    try {
      return registeredUsers.firstWhere(
        (user) =>
            (isMoxId ? user.moxId == input : user.phone == input) &&
            user.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // AUTHENTICATE ASYNC
  // ============================================================

  static Future<UserModel?> authenticateAsync(
    String input,
    String password,
    bool isMoxId,
  ) async {
    await ensureLoaded();

    // البحث المحلي أولاً
    UserModel? foundUser = authenticate(input, password, isMoxId);

    if (foundUser != null) {
      return foundUser;
    }

    // البحث المباشر في Google
    try {
      debugPrint('🌐 [Cloud Fallback] البحث المباشر في Google Sheets...');

      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return null;
      }

      for (final item in decoded) {
        try {
          final Map<String, dynamic> mapItem = Map<String, dynamic>.from(item);

          if ((mapItem['moxId'] == null ||
                  mapItem['moxId'].toString().trim().isEmpty) &&
              mapItem['MOXID'] != null) {
            mapItem['moxId'] = mapItem['MOXID'];
          }

          final UserModel cloudUser = UserModel.fromJson(mapItem);

          final bool identifierMatches = isMoxId
              ? cloudUser.moxId == input
              : cloudUser.phone == input;

          final bool passwordMatches = cloudUser.password == password;

          if (identifierMatches && passwordMatches) {
            foundUser = cloudUser;

            final int index = registeredUsers.indexWhere(
              (user) =>
                  user.moxId == cloudUser.moxId ||
                  user.phone == cloudUser.phone,
            );

            if (index >= 0) {
              registeredUsers[index] = cloudUser;
            } else {
              registeredUsers.add(cloudUser);
            }

            await saveUsersList();

            debugPrint('✅ [Cloud Fallback] تم استدعاء العميل وحفظه محلياً.');

            return foundUser;
          }
        } catch (e) {
          debugPrint('⚠️ [Cloud Auth] تجاهل سجل غير صالح: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [Cloud Auth] فشل الاتصال بالسحابة: $e');
    }

    return null;
  }

  // ============================================================
  // GET USER BY MOX ID
  // ============================================================

  static Future<UserModel?> getUserByMoxId(String moxId) async {
    try {
      await ensureLoaded();

      final String target = moxId.trim().toUpperCase();

      return registeredUsers.firstWhere(
        (user) =>
            user.moxId.trim().toUpperCase() == target ||
            (user.guardianMoxId ?? '').trim().toUpperCase() == target ||
            (user.guardianMoxIdCustomer ?? '').trim().toUpperCase() == target,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // PUBLIC IDENTIFIER - LOCAL
  // ============================================================

  static Future<UserModel?> getUserByPublicIdentifier(String identifier) async {
    try {
      await ensureLoaded();

      final String target = identifier.trim().toUpperCase();

      if (target.isEmpty) {
        return null;
      }

      for (final user in registeredUsers) {
        if (user.moxId.trim().toUpperCase() == target) {
          return user;
        }

        if ((user.guardianMoxId ?? '').trim().toUpperCase() == target) {
          return user;
        }

        if ((user.guardianMoxIdCustomer ?? '').trim().toUpperCase() == target) {
          return user;
        }

        if (user.phone.trim() == identifier.trim()) {
          return user;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Public Identifier] خطأ محلي: $e');
    }

    return null;
  }

  // ============================================================
  // PUBLIC IDENTIFIER - CLOUD
  // ============================================================

  static Future<UserModel?> getUserByPublicIdentifierFromCloud(
    String identifier,
  ) async {
    try {
      final String target = identifier.trim().toUpperCase();

      if (target.isEmpty) {
        return null;
      }

      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return null;
      }

      for (final item in decoded) {
        try {
          final Map<String, dynamic> mapItem = Map<String, dynamic>.from(item);

          if ((mapItem['moxId'] == null ||
                  mapItem['moxId'].toString().trim().isEmpty) &&
              mapItem['MOXID'] != null) {
            mapItem['moxId'] = mapItem['MOXID'];
          }

          final UserModel user = UserModel.fromJson(mapItem);

          final bool match =
              user.moxId.trim().toUpperCase() == target ||
              (user.guardianMoxId ?? '').trim().toUpperCase() == target ||
              (user.guardianMoxIdCustomer ?? '').trim().toUpperCase() ==
                  target ||
              user.phone.trim() == identifier.trim();

          if (match) {
            final int index = registeredUsers.indexWhere(
              (local) => local.moxId == user.moxId || local.phone == user.phone,
            );

            if (index >= 0) {
              registeredUsers[index] = user;
            } else {
              registeredUsers.add(user);
            }

            await saveUsersList();

            return user;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ [Public Identifier Cloud] $e');
    }

    return null;
  }

  // ============================================================
  // CLIENT CARDS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getClientCards(String moxId) async {
    try {
      final UserModel? user = await getUserByMoxId(moxId);

      if (user != null && user.myAssets.isNotEmpty) {
        final List<Map<String, dynamic>> formattedAssets = [];

        for (final MarketingCard asset in user.myAssets) {
          formattedAssets.add(asset.toJson());
        }

        return formattedAssets;
      }
    } catch (e) {
      debugPrint('⚠️ [Client Cards] $e');
    }

    // بطاقة احتياطية
    return [
      {
        'title': 'بطاقة المتجر السيادي الفاخرة',
        'description': 'منتج معتمد ومتاح للطلب الفوري عبر السوق المفتوح.',
        'price': 0.0,
        'whatsapp': '249115855164',
        'facebookUrl': '',
        'category': 'بطاقة',
        'isApproved': true,
      },
    ];
  }
}
