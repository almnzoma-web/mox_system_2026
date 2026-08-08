import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../models/marketing_card.dart';

class StorageService {
  static const String userKey = 'current_mox_user';

  static const String savedUsersKey = 'saved_users';

  static List<UserModel> registeredUsers = [];

  static bool _isLoaded = false;

  // ============================================================
  // GOOGLE APPS SCRIPT
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

  // ============================================================
  // ADMIN
  // ============================================================

  static final UserModel adminUser = UserModel(
    phone: '249115855164',
    password: '',
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
    guardianMoxId: 'MOX249-00010001',
    guardianMoxIdCustomer: 'MOX249-00010001',
    points: 0,
    myAssets: const [],
  );

  // ============================================================
  // ADMIN ID CHECK
  // ============================================================

  static bool _isAdminIdentity({String? phone, String? moxId}) {
    final cleanPhone = phone?.trim() ?? '';
    final cleanMoxId = moxId?.trim() ?? '';

    return cleanPhone == adminUser.phone || cleanMoxId == adminUser.moxId;
  }

  static bool _isAdminUser(UserModel user) {
    return _isAdminIdentity(phone: user.phone, moxId: user.moxId);
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  static Future<void> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      final encodedData = prefs.getString(savedUsersKey);

      registeredUsers = [];

      if (encodedData != null && encodedData.isNotEmpty) {
        try {
          final decoded = json.decode(encodedData);

          if (decoded is List) {
            registeredUsers = decoded
                .whereType<Map>()
                .map(
                  (item) => UserModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
          }
        } catch (e) {
          debugPrint('❌ [Local JSON] بيانات المستخدمين تالفة: $e');
        }
      }

      _ensureAdmin();

      await saveUsersList();

      _isLoaded = true;

      _syncFromCloudInBackground();
    } catch (e) {
      debugPrint('❌ [Hybrid Local] خطأ في التحميل المحلي: $e');

      registeredUsers = [adminUser];

      _isLoaded = true;
    }
  }

  // ============================================================
  // ENSURE ADMIN
  // ============================================================

  static void _ensureAdmin() {
    final index = registeredUsers.indexWhere((u) => u.moxId == adminUser.moxId);

    if (index == -1) {
      registeredUsers.insert(0, adminUser);
    } else {
      registeredUsers[index] = adminUser;
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

      final dynamic decoded = json.decode(response.body);

      if (decoded is! List) {
        return;
      }

      final List<UserModel> cloudUsers = [];

      for (final item in decoded) {
        try {
          if (item is! Map) {
            continue;
          }

          final mapItem = Map<String, dynamic>.from(item);

          if ((mapItem['moxId'] == null ||
                  mapItem['moxId'].toString().trim().isEmpty) &&
              mapItem['MOXID'] != null) {
            mapItem['moxId'] = mapItem['MOXID'];
          }

          final cloudUser = UserModel.fromJson(mapItem);

          if (cloudUser.moxId.trim().isEmpty || cloudUser.moxId == 'null') {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint('⚠️ [Cloud User] تخطي مستخدم غير صالح: $e');
        }
      }

      for (final cloudUser in cloudUsers) {
        final index = registeredUsers.indexWhere(
          (u) => u.moxId == cloudUser.moxId || u.phone == cloudUser.phone,
        );

        if (index == -1) {
          registeredUsers.add(cloudUser);
        } else {
          registeredUsers[index] = cloudUser;
        }
      }

      _ensureAdmin();

      await saveUsersList();
    } catch (e) {
      debugPrint('❌ [Cloud Sync] $e');
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
  // SAVE LOCAL
  // ============================================================

  static Future<void> saveUsersList() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final jsonList = registeredUsers.map((u) => u.toJson()).toList();

      await prefs.setString(savedUsersKey, json.encode(jsonList));

      _isLoaded = true;
    } catch (e) {
      debugPrint('❌ [Local Save] $e');
    }
  }

  // ============================================================
  // ASSETS JSON
  // ============================================================

  static String _encodeAssets(List<MarketingCard> assets) {
    try {
      return json.encode(assets.map((a) => a.toJson()).toList());
    } catch (e) {
      debugPrint('❌ [Assets JSON] $e');

      return '[]';
    }
  }

  // ============================================================
  // CLOUD PARAMETERS
  // ============================================================

  static Map<String, String> _userCloudParameters(UserModel user) {
    final params = <String, String>{
      'action': 'save',

      'phone': user.phone,

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

      'storePublishDate': user.storePublishDate ?? '',

      'activationDate': user.activationDate ?? '',
    };

    if (!_isAdminUser(user)) {
      params['password'] = user.password;
    }

    return params;
  }

  // ============================================================
  // ADD USER
  // ============================================================

  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    if (newUser.moxId.trim().isEmpty || newUser.moxId == 'null') {
      debugPrint('❌ محاولة حفظ مستخدم بدون MoxId تم رفضها.');
      return;
    }

    final index = registeredUsers.indexWhere(
      (u) => u.phone == newUser.phone || u.moxId == newUser.moxId,
    );

    if (index != -1) {
      registeredUsers[index] = newUser;
    } else {
      registeredUsers.add(newUser);
    }

    _ensureAdmin();

    await saveUsersList();

    await _saveToCloud(newUser);
  }

  // ============================================================
  // UPDATE USER PARTIAL
  // ============================================================

  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (user.moxId.trim().isEmpty || user.moxId == 'null') {
      throw Exception('لا يمكن تحديث المستخدم بدون MoxId.');
    }

    final bool cloudSaved = await _saveToCloud(user);

    if (!cloudSaved) {
      throw Exception('تعذر حفظ بيانات المتجر في Google Sheet.');
    }

    final index = registeredUsers.indexWhere(
      (u) => u.moxId == user.moxId || u.phone == user.phone,
    );

    if (index != -1) {
      registeredUsers[index] = user;
    } else {
      registeredUsers.add(user);
    }

    _ensureAdmin();

    await saveUsersList();

    try {
      final prefs = await SharedPreferences.getInstance();

      final currentUserJson = prefs.getString(userKey);

      if (currentUserJson != null && currentUserJson.isNotEmpty) {
        final activeUser = UserModel.fromJson(jsonDecode(currentUserJson));

        if (activeUser.moxId == user.moxId || activeUser.phone == user.phone) {
          await prefs.setString(userKey, jsonEncode(user.toJson()));
        }
      }
    } catch (e) {
      debugPrint('❌ [Session Cache] $e');
    }
  }

  // ============================================================
  // SAVE TO CLOUD
  // ============================================================

  static Future<bool> _saveToCloud(UserModel user) async {
    try {
      final uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      debugPrint('☁️ [Cloud Save] HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ [Cloud Save] HTTP Error: ${response.body}');
        return false;
      }

      try {
        final dynamic decoded = json.decode(response.body);

        if (decoded is Map) {
          final status = decoded['status']?.toString().toLowerCase();

          if (status == 'error' || status == 'failed' || status == 'failure') {
            debugPrint('❌ [Cloud Save] Apps Script رفض الحفظ: $decoded');
            return false;
          }
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('❌ [Cloud Save Exception] $e');

      return false;
    }
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
      debugPrint('❌ [Active User] $e');
    }
  }

  // ============================================================
  // GET ACTIVE USER
  // ============================================================

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userJson = prefs.getString(userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      final user = UserModel.fromJson(jsonDecode(userJson));

      if (_isAdminUser(user)) {
        return adminUser;
      }

      return user;
    } catch (e) {
      debugPrint('❌ [Get User] $e');

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
    } catch (_) {}
  }

  // ============================================================
  // CLIENT DATA
  // ============================================================

  static Future<Object?> getClientsData() async {
    await ensureLoaded();

    return registeredUsers.map((u) => u.toJson()).toList();
  }

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {
    registeredUsers = clientsData.map((e) => UserModel.fromJson(e)).toList();

    _ensureAdmin();

    _isLoaded = true;

    await saveUsersList();
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

    final cleanInput = input.trim();

    final cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    final isAdminLogin = _isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      moxId: isMoxId ? cleanInput : null,
    );

    // ========================================================
    // LOCAL LOGIN
    // ========================================================

    if (!isAdminLogin) {
      try {
        final foundUser = registeredUsers.firstWhere(
          (u) =>
              (isMoxId
                  ? u.moxId.trim() == cleanInput
                  : u.phone.trim() == cleanInput) &&
              u.password == cleanPassword,
        );

        return foundUser;
      } catch (_) {}
    }

    // ========================================================
    // CLOUD LOGIN
    // ========================================================

    try {
      final uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',

          'input': cleanInput,

          'password': cleanPassword,

          'isMoxId': isMoxId.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);

      if (map['status'] != 'success') {
        return null;
      }

      final dynamic rawUser = map['user'];

      if (rawUser is! Map) {
        return null;
      }

      final cloudUser = UserModel.fromJson(Map<String, dynamic>.from(rawUser));

      // ======================================================
      // ADMIN
      // ======================================================

      if (_isAdminUser(cloudUser)) {
        final safeAdmin = adminUser.copyWith(
          name: cloudUser.name,
          address: cloudUser.address,
          storeDescription: cloudUser.storeDescription,
          balance: cloudUser.balance,
          commission: cloudUser.commission,
          role: cloudUser.role,
          guardianMoxId: cloudUser.guardianMoxId,
          guardianMoxIdCustomer: cloudUser.guardianMoxIdCustomer,
          storePublishDate: cloudUser.storePublishDate,
          activationDate: cloudUser.activationDate,
          points: cloudUser.points,
          myAssets: cloudUser.myAssets,
        );

        final index = registeredUsers.indexWhere(
          (u) => u.moxId == adminUser.moxId,
        );

        if (index == -1) {
          registeredUsers.insert(0, safeAdmin);
        } else {
          registeredUsers[index] = safeAdmin;
        }

        await saveUsersList();

        return safeAdmin;
      }

      // ======================================================
      // NORMAL USER
      // ======================================================

      final index = registeredUsers.indexWhere(
        (u) => u.moxId == cloudUser.moxId || u.phone == cloudUser.phone,
      );

      if (index == -1) {
        registeredUsers.add(cloudUser);
      } else {
        registeredUsers[index] = cloudUser;
      }

      await saveUsersList();

      return cloudUser;
    } catch (e) {
      debugPrint('❌ [Cloud Login] $e');

      return null;
    }
  }

  // ============================================================
  // AUTHENTICATE SYNC
  // ============================================================

  static UserModel? authenticate(String input, String password, bool isMoxId) {
    final cleanInput = input.trim();

    final cleanPassword = password.trim();

    if (_isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      moxId: isMoxId ? cleanInput : null,
    )) {
      return null;
    }

    try {
      return registeredUsers.firstWhere(
        (u) =>
            (isMoxId
                ? u.moxId.trim() == cleanInput
                : u.phone.trim() == cleanInput) &&
            u.password == cleanPassword,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // USER BY MOX ID
  // ============================================================

  static Future<UserModel?> getUserByMoxId(String moxId) async {
    final cleanMoxId = moxId.trim();

    if (cleanMoxId.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse('$_scriptUrl?action=getAll'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }

            try {
              final mapItem = Map<String, dynamic>.from(item);

              if ((mapItem['moxId'] == null ||
                      mapItem['moxId'].toString().trim().isEmpty) &&
                  mapItem['MOXID'] != null) {
                mapItem['moxId'] = mapItem['MOXID'];
              }

              final cloudUser = UserModel.fromJson(mapItem);

              final bool matched =
                  cloudUser.moxId.trim() == cleanMoxId ||
                  cloudUser.guardianMoxId?.trim() == cleanMoxId ||
                  cloudUser.guardianMoxIdCustomer?.trim() == cleanMoxId;

              if (!matched) {
                continue;
              }

              final index = registeredUsers.indexWhere(
                (u) => u.moxId == cloudUser.moxId || u.phone == cloudUser.phone,
              );

              if (index == -1) {
                registeredUsers.add(cloudUser);
              } else {
                registeredUsers[index] = cloudUser;
              }

              _ensureAdmin();

              await saveUsersList();

              return cloudUser;
            } catch (e) {
              debugPrint('⚠️ [Cloud User Parse] $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Cloud User Fetch] $e');
    }

    try {
      await ensureLoaded();

      return registeredUsers.firstWhere(
        (u) =>
            u.moxId.trim() == cleanMoxId ||
            u.guardianMoxId?.trim() == cleanMoxId ||
            u.guardianMoxIdCustomer?.trim() == cleanMoxId,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // CLIENT CARDS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getClientCards(String moxId) async {
    try {
      final user = await getUserByMoxId(moxId);

      if (user != null && user.myAssets.isNotEmpty) {
        return user.myAssets.map((card) => card.toJson()).toList();
      }
    } catch (_) {}

    return [
      {
        'title': 'بطاقة المتجر السيادي الفاخرة',
        'description': 'منتج معتمد ومتاح للطلب الفوري عبر السوق المفتوح.',
        'category': 'متجر وتجارة',
        'iconKey': 'store',
        'price': 0.0,
        'whatsapp': '249115855164',
        'facebookUrl': '',
        'isApproved': true,
      },
    ];
  }
}
