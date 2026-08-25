// ignore_for_file: unused_element

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/marketing_card.dart';
import '../models/user_model.dart';

class StorageService {
  // ============================================================
  // LOCAL KEYS
  // ============================================================

  static const String userKey = 'current_mox_user';

  static const String savedUsersKey = 'saved_users';

  static const String localUsersVersionKey = 'mox_local_users_version';

  // ============================================================
  // مهم جداً:
  //
  // هذا الرقم لا يستخدم لمسح العملاء.
  // يمكن تغييره مستقبلاً، لكن migration لن تحذف saved_users.
  // ============================================================

  static const int currentLocalUsersVersion = 3;

  // ============================================================
  // RUNTIME MEMORY
  // ============================================================

  static List<UserModel> registeredUsers = [];

  static bool _isLoaded = false;

  static bool _cloudSyncRunning = false;

  // ============================================================
  // GOOGLE APPS SCRIPT
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbzqlQEPgt-UxO5fyVq4bEOezHO8fKd7VXnP9v6oIjM8WqIKZuRCOmHdjNrZ8KG_K4wL/exec';

  // ============================================================
  // VERCEL STORE API
  // ============================================================

  static const String _vercelStoreUrl = 'https://mox-2026.vercel.app/api/store';

  // ============================================================
  // STORE ACTIVATION
  // ============================================================

  static const String _activationAction = 'activateStore';

  static const int storeSubscriptionDays = 365;

  // ============================================================
  // HTML GUARD
  // ============================================================

  static bool _isHtmlResponse(String body) {
    final String trimmed = body.trim().toLowerCase();

    return trimmed.startsWith('<') ||
        trimmed.startsWith('<!doctype') ||
        trimmed.contains('<html');
  }

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
  // NORMALIZE
  // ============================================================

  static String _clean(String? value) {
    return value?.trim() ?? '';
  }

  static bool _isValidMoxId(String? value) {
    final String id = _clean(value);

    return id.isNotEmpty &&
        id.toLowerCase() != 'null' &&
        id.toLowerCase() != 'undefined' &&
        id.toLowerCase() != 'لم يحدد';
  }

  // ============================================================
  // NORMALIZE USER MAP
  // ============================================================

  static Map<String, dynamic> _normalizeUserMap(Map<String, dynamic> source) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(source);

    dynamic findValue(List<String> keys) {
      for (final String wanted in keys) {
        for (final MapEntry<String, dynamic> entry in source.entries) {
          if (entry.key.trim().toLowerCase() == wanted.trim().toLowerCase()) {
            return entry.value;
          }
        }
      }

      return null;
    }

    void setIfFound(String target, List<String> aliases) {
      final dynamic value = findValue(aliases);

      if (value != null) {
        result[target] = value;
      }
    }

    setIfFound('moxId', ['moxId', 'MOXID', 'mox_id']);

    setIfFound('storePublishDate', [
      'storePublishDate',
      'storepublishdate',
      'store_publish_date',
    ]);

    setIfFound('activationDate', [
      'activationDate',
      'activationdate',
      'activation_date',
    ]);

    setIfFound('myAssets', ['myAssets', 'myassets', 'my_assets']);

    // ----------------------------------------------------------
    // Assets JSON
    // ----------------------------------------------------------

    final dynamic assets = result['myAssets'];

    if (assets is String && assets.trim().isNotEmpty) {
      try {
        final dynamic decodedAssets = json.decode(assets);

        if (decodedAssets is List) {
          result['myAssets'] = decodedAssets;
        }
      } catch (_) {}
    }

    return result;
  }

  // ============================================================
  // GUARDIAN VALIDATION
  // ============================================================

  static bool _isValidGuardianMoxId(String? value) {
    final String id = _clean(value).toUpperCase();

    return id.isNotEmpty &&
        id != 'NULL' &&
        id != 'UNDEFINED' &&
        id != 'N/A' &&
        id != 'لم يحدد';
  }

  // ============================================================
  // ADMIN ID CHECK
  // ============================================================

  static bool _isAdminIdentity({
    String? phone,
    String? cleanGuardianMoxId,
    String? guardianMoxId,
  }) {
    final String cleanPhone = _clean(phone);

    final String cleanGuardian = _clean(
      cleanGuardianMoxId ?? guardianMoxId,
    ).toUpperCase();

    return cleanPhone == adminUser.phone ||
        cleanGuardian == _clean(adminUser.guardianMoxId).toUpperCase();
  }

  static bool _isAdminUser(UserModel user) {
    return _isAdminIdentity(
      phone: user.phone,
      guardianMoxId: user.guardianMoxId,
    );
  }

  // ============================================================
  // LOAD USERS
  //
  // مهم:
  // لا نمسح saved_users عند تحديث التطبيق.
  // ============================================================

  static Future<void> loadUsers() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      await _migrateLocalUsersIfNeeded(prefs);

      final String? encodedData = prefs.getString(savedUsersKey);

      final List<UserModel> localUsers = [];

      if (encodedData != null && encodedData.trim().isNotEmpty) {
        try {
          final dynamic decoded = json.decode(encodedData);

          if (decoded is List) {
            for (final dynamic item in decoded) {
              if (item is! Map) {
                continue;
              }

              try {
                final Map<String, dynamic> rawMap = Map<String, dynamic>.from(
                  item,
                );

                final Map<String, dynamic> normalized = _normalizeUserMap(
                  rawMap,
                );

                final UserModel user = UserModel.fromJson(normalized);

                // المدير يمكن أن يبقى بدون moxId صالح
                if (!_isAdminUser(user) && !_isValidMoxId(user.moxId)) {
                  continue;
                }

                localUsers.add(user);
              } catch (e) {
                debugPrint(
                  '⚠️ [Local User Parse] '
                  'تخطي مستخدم: $e',
                );
              }
            }
          }
        } catch (e) {
          debugPrint(
            '❌ [Local JSON] '
            'بيانات المستخدمين تالفة: $e',
          );
        }
      }

      registeredUsers = localUsers;

      _ensureAdmin();

      _isLoaded = true;

      debugPrint(
        '✅ [BOOT] Local users loaded: '
        '${registeredUsers.length}',
      );
    } catch (e) {
      debugPrint(
        '❌ [Hybrid Local] '
        'خطأ في التحميل المحلي: $e',
      );

      registeredUsers = [adminUser];

      _isLoaded = true;
    }
  }

  // ============================================================
  // LOCAL MEMORY MIGRATION
  //
  // 🚨 لا نحذف saved_users أبداً عند تحديث الإصدار.
  // ============================================================

  static Future<void> _migrateLocalUsersIfNeeded(
    SharedPreferences prefs,
  ) async {
    try {
      final int savedVersion = prefs.getInt(localUsersVersionKey) ?? 0;

      if (savedVersion >= currentLocalUsersVersion) {
        return;
      }

      debugPrint(
        '🔄 [Local Migration] '
        'تحديث إصدار ذاكرة العملاء '
        '$savedVersion -> '
        '$currentLocalUsersVersion',
      );

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      debugPrint(
        '✅ [Local Migration] '
        'تم تحديث الإصدار مع الحفاظ '
        'على بيانات العملاء.',
      );
    } catch (e) {
      debugPrint('❌ [Local Migration] $e');
    }
  }

  // ============================================================
  // ENSURE ADMIN
  // ============================================================

  static void _ensureAdmin() {
    final int index = registeredUsers.indexWhere((u) => _isAdminUser(u));

    if (index == -1) {
      registeredUsers.insert(0, adminUser);
    } else {
      registeredUsers[index] = adminUser;
    }
  }

  // ============================================================
  // FIND LOCAL USER
  // ============================================================

  static UserModel? _findLocalUser(UserModel user) {
    try {
      return registeredUsers.firstWhere(
        (u) => u.moxId == user.moxId || u.phone == user.phone,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // PRESERVE SUBSCRIPTION
  // ============================================================

  static UserModel _preserveSubscriptionState({
    required UserModel? oldUser,
    required UserModel newUser,
  }) {
    if (oldUser == null) {
      return newUser;
    }

    final String oldPublishDate = _clean(oldUser.storePublishDate);

    final String oldActivationDate = _clean(oldUser.activationDate);

    return newUser.copyWith(
      storePublishDate: oldPublishDate.isNotEmpty
          ? oldPublishDate
          : newUser.storePublishDate,
      activationDate: oldActivationDate.isNotEmpty
          ? oldActivationDate
          : newUser.activationDate,
    );
  }

  // ============================================================
  // ENSURE LOADED
  // ============================================================

  static Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await loadUsers();
      return;
    }

    if (registeredUsers.isEmpty) {
      await loadUsers();
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
    final UserModel? existingLocalUser = _findLocalUser(user);

    final bool shouldSendPassword =
        user.password.trim().isNotEmpty &&
        (existingLocalUser == null ||
            existingLocalUser.password.trim().isEmpty);

    return <String, String>{
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

      'password': shouldSendPassword ? user.password : '',

      'storePublishDate': user.storePublishDate ?? '',

      'activationDate': user.activationDate ?? '',

      'digitalPublicKey': user.digitalPublicKey ?? '',

      'digitalSignatureAlgorithm': user.digitalSignatureAlgorithm,

      'digitalSignatureCreatedAt': user.digitalSignatureCreatedAt ?? '',

      'digitalSignatureKeyVersion': user.digitalSignatureKeyVersion.toString(),
    };
  }

  // ============================================================
  // SAVE TO CLOUD
  // ============================================================

  static Future<bool> _saveToCloud(UserModel user) async {
    try {
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      debugPrint(
        '☁️ [Cloud Save] '
        'إرسال بيانات: '
        '${user.moxId}',
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '☁️ [Cloud Save] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '❌ [Cloud Save] HTTP Error: '
          '${response.body}',
        );

        return false;
      }

      if (_isHtmlResponse(response.body)) {
        debugPrint(
          '❌ [Cloud Save] '
          'الاستجابة HTML.',
        );

        return false;
      }

      try {
        final dynamic decoded = json.decode(response.body);

        if (decoded is Map) {
          final String status =
              decoded['status']?.toString().toLowerCase() ?? '';

          if (status == 'error' || status == 'failed' || status == 'failure') {
            debugPrint(
              '❌ [Cloud Save] '
              'Apps Script رفض الحفظ: '
              '$decoded',
            );

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
  // SAVE LOCAL USERS
  // ============================================================

  static Future<void> saveUsersList() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> jsonList = registeredUsers
          .where((u) => _isAdminUser(u) || _isValidMoxId(u.moxId))
          .map((u) => u.toJson())
          .toList();

      await prefs.setString(savedUsersKey, json.encode(jsonList));

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      _isLoaded = true;

      debugPrint(
        '💾 [Local Save] '
        'تم حفظ ${jsonList.length} مستخدم محلياً.',
      );
    } catch (e) {
      debugPrint('❌ [Local Save] $e');
    }
  }

  // ============================================================
  // ADD USER
  // ============================================================

  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    if (!_isValidMoxId(newUser.moxId)) {
      debugPrint(
        '❌ محاولة حفظ مستخدم '
        'بدون MoxId تم رفضها.',
      );

      return;
    }

    final UserModel? oldUser = _findLocalUser(newUser);

    final UserModel protectedUser = _preserveSubscriptionState(
      oldUser: oldUser,
      newUser: newUser,
    );

    final bool cloudSaved = await _saveToCloud(protectedUser);

    if (!cloudSaved) {
      debugPrint(
        '⚠️ [Add User] '
        'فشل الحفظ السحابي، '
        'سيتم الاحتفاظ بالنسخة المحلية.',
      );
    }

    final int index = registeredUsers.indexWhere(
      (u) => u.moxId == protectedUser.moxId || u.phone == protectedUser.phone,
    );

    if (index == -1) {
      registeredUsers.add(protectedUser);
    } else {
      registeredUsers[index] = protectedUser;
    }

    _ensureAdmin();

    await saveUsersList();
  }

  // ============================================================
  // UPDATE USER PARTIAL
  // ============================================================

  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (!_isValidMoxId(user.moxId)) {
      throw Exception('لا يمكن تحديث المستخدم بدون MoxId.');
    }

    final UserModel? oldUser = _findLocalUser(user);

    final UserModel protectedUser = _preserveSubscriptionState(
      oldUser: oldUser,
      newUser: user,
    );

    final bool cloudSaved = await _saveToCloud(protectedUser);

    if (!cloudSaved) {
      throw Exception('تعذر حفظ بيانات المتجر في Google Sheet.');
    }

    final int index = registeredUsers.indexWhere(
      (u) => u.moxId == protectedUser.moxId || u.phone == protectedUser.phone,
    );

    if (index == -1) {
      registeredUsers.add(protectedUser);
    } else {
      registeredUsers[index] = protectedUser;
    }

    _ensureAdmin();

    await saveUsersList();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? currentUserJson = prefs.getString(userKey);

      if (currentUserJson != null && currentUserJson.isNotEmpty) {
        final UserModel activeUser = UserModel.fromJson(
          jsonDecode(currentUserJson),
        );

        if (activeUser.moxId == protectedUser.moxId ||
            activeUser.phone == protectedUser.phone) {
          await prefs.setString(userKey, jsonEncode(protectedUser.toJson()));
        }
      }
    } catch (e) {
      debugPrint('❌ [Session Cache] $e');
    }
  }

  // ============================================================
  // SAVE ACTIVE USER
  // ============================================================

  static Future<void> saveUser(UserModel user) async {
    try {
      await ensureLoaded();

      final UserModel? oldUser = _findLocalUser(user);

      final UserModel protectedUser = _preserveSubscriptionState(
        oldUser: oldUser,
        newUser: user,
      );

      final bool cloudSaved = await _saveToCloud(protectedUser);

      if (!cloudSaved) {
        throw Exception('تعذر حفظ بيانات المتجر في Google Sheet.');
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(protectedUser.toJson()));

      final int index = registeredUsers.indexWhere(
        (u) => u.moxId == protectedUser.moxId || u.phone == protectedUser.phone,
      );

      if (index == -1) {
        registeredUsers.add(protectedUser);
      } else {
        registeredUsers[index] = protectedUser;
      }

      _ensureAdmin();

      await saveUsersList();

      debugPrint(
        '✅ [Active User] '
        'تم حفظ المتجر مع الحفاظ على الاشتراك.',
      );
    } catch (e) {
      debugPrint('❌ [Active User] $e');

      rethrow;
    }
  }

  // ============================================================
  // GET ACTIVE USER
  // ============================================================

  static Future<UserModel?> getUser() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      final String? userJson = prefs.getString(userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      final UserModel user = UserModel.fromJson(jsonDecode(userJson));

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
      final SharedPreferences prefs = await SharedPreferences.getInstance();

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

  // ============================================================
  // SAVE CLIENTS DATA
  // ============================================================

  static Future<void> saveClientsData(
    List<Map<String, dynamic>> clientsData,
  ) async {
    final List<UserModel> users = [];

    for (final Map<String, dynamic> data in clientsData) {
      try {
        final Map<String, dynamic> normalized = _normalizeUserMap(data);

        final UserModel user = UserModel.fromJson(normalized);

        if (!_isValidMoxId(user.moxId)) {
          continue;
        }

        if (_isAdminUser(user)) {
          continue;
        }

        users.add(user);
      } catch (e) {
        debugPrint(
          '⚠️ [Save Clients Data] '
          'تخطي سجل: $e',
        );
      }
    }

    registeredUsers = users;

    _ensureAdmin();

    _isLoaded = true;

    await saveUsersList();
  }

  // ============================================================
  // FETCH ALL USERS FROM VERCEL
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromVercel() async {
    try {
      final Uri uri = Uri.parse(
        _vercelStoreUrl,
      ).replace(queryParameters: {'action': 'getAll'});

      debugPrint('☁️ [Vercel GetAll] GET $uri');

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '☁️ [Vercel GetAll] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return null;
      }

      if (_isHtmlResponse(response.body)) {
        debugPrint(
          '❌ [Vercel GetAll] '
          'السيرفر أعاد HTML.',
        );

        return null;
      }

      final dynamic decoded = json.decode(response.body);

      List<dynamic> rawUsers = [];

      if (decoded is Map && decoded['users'] is List) {
        rawUsers = List<dynamic>.from(decoded['users']);
      } else if (decoded is Map && decoded['data'] is List) {
        rawUsers = List<dynamic>.from(decoded['data']);
      } else if (decoded is List) {
        rawUsers = List<dynamic>.from(decoded);
      } else {
        debugPrint(
          '❌ [Vercel GetAll] '
          'لا توجد قائمة users.',
        );

        return null;
      }

      final List<UserModel> cloudUsers = [];

      for (final dynamic item in rawUsers) {
        if (item is! Map) {
          continue;
        }

        try {
          final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item);

          final Map<String, dynamic> mapItem = _normalizeUserMap(rawMap);

          final UserModel cloudUser = UserModel.fromJson(mapItem);

          if (!_isValidMoxId(cloudUser.moxId)) {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint(
            '⚠️ [Vercel Cloud User Parse] '
            '$e',
          );
        }
      }

      debugPrint(
        '✅ [Vercel GetAll] '
        'تم تحليل '
        '${cloudUsers.length} '
        'عميل.',
      );

      return cloudUsers;
    } catch (e) {
      debugPrint('❌ [Vercel GetAll Exception] $e');

      return null;
    }
  }

  // ============================================================
  // FETCH ALL USERS FROM GOOGLE APPS SCRIPT
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromGoogle() async {
    try {
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: {'action': 'getAll'});

      debugPrint('☁️ [Google GetAll] GET $uri');

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '☁️ [Google GetAll] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return null;
      }

      if (_isHtmlResponse(response.body)) {
        return null;
      }

      final dynamic decoded = json.decode(response.body);

      List<dynamic> rawUsers = [];

      if (decoded is Map && decoded['users'] is List) {
        rawUsers = List<dynamic>.from(decoded['users']);
      } else if (decoded is Map && decoded['data'] is List) {
        rawUsers = List<dynamic>.from(decoded['data']);
      } else if (decoded is List) {
        rawUsers = List<dynamic>.from(decoded);
      } else {
        return null;
      }

      final List<UserModel> cloudUsers = [];

      for (final dynamic item in rawUsers) {
        if (item is! Map) {
          continue;
        }

        try {
          final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item);

          final Map<String, dynamic> normalized = _normalizeUserMap(rawMap);

          final UserModel cloudUser = UserModel.fromJson(normalized);

          if (!_isValidMoxId(cloudUser.moxId)) {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint(
            '⚠️ [Google Cloud User Parse] '
            '$e',
          );
        }
      }

      debugPrint(
        '✅ [Google GetAll] '
        'تم تحليل '
        '${cloudUsers.length} '
        'عميل.',
      );

      return cloudUsers;
    } catch (e) {
      debugPrint('❌ [Google GetAll Exception] $e');

      return null;
    }
  }

  // ============================================================
  // FETCH ALL USERS
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromCloud() async {
    final List<UserModel>? vercelUsers = await _fetchAllUsersFromVercel();

    if (vercelUsers != null) {
      return vercelUsers;
    }

    debugPrint(
      '⚠️ [Cloud GetAll] '
      'Vercel فشل، نجرب Google Apps Script...',
    );

    final List<UserModel>? googleUsers = await _fetchAllUsersFromGoogle();

    if (googleUsers != null) {
      return googleUsers;
    }

    debugPrint(
      '⚠️ [Cloud GetAll] '
      'Vercel و Google فشلا.',
    );

    return null;
  }

  // ============================================================
  // SYNC CLIENTS
  // ============================================================

  static Future<bool> syncClientsFromCloud({bool saveLocal = true}) async {
    if (_cloudSyncRunning) {
      return false;
    }

    _cloudSyncRunning = true;

    try {
      await ensureLoaded();

      final List<UserModel>? cloudUsers = await _fetchAllUsersFromCloud();

      if (cloudUsers == null) {
        debugPrint(
          '⚠️ [Cloud Sync] '
          'فشل جلب العملاء. '
          'سيتم الاحتفاظ بالـ Local Cache.',
        );

        return false;
      }

      registeredUsers = [];

      for (final UserModel cloudUser in cloudUsers) {
        if (_isAdminUser(cloudUser)) {
          continue;
        }

        if (!_isValidMoxId(cloudUser.moxId)) {
          continue;
        }

        registeredUsers.add(cloudUser);
      }

      _ensureAdmin();

      if (saveLocal) {
        await saveUsersList();
      }

      debugPrint(
        '☁️ [Cloud Sync] '
        'تم تحديث العملاء من السحابة: '
        '${registeredUsers.length - 1} '
        'عميل.',
      );

      return true;
    } catch (e) {
      debugPrint('❌ [Cloud Sync] $e');

      return false;
    } finally {
      _cloudSyncRunning = false;
    }
  }

  // ============================================================
  // ADMIN SYNC
  // ============================================================

  static Future<bool> syncAdminData() async {
    try {
      await ensureLoaded();

      final UserModel? activeAdmin = await _fetchAdminFromCloud();

      if (activeAdmin != null) {
        final UserModel safeAdmin = adminUser.copyWith(
          name: activeAdmin.name,
          address: activeAdmin.address,
          balance: activeAdmin.balance,
          commission: activeAdmin.commission,
          role: activeAdmin.role,
          guardianMoxId: activeAdmin.guardianMoxId,
          guardianMoxIdCustomer: activeAdmin.guardianMoxIdCustomer,
          points: activeAdmin.points,
          myAssets: activeAdmin.myAssets,
          storeDescription: activeAdmin.storeDescription,
          storePublishDate: activeAdmin.storePublishDate,
          activationDate: activeAdmin.activationDate,
          digitalPublicKey: activeAdmin.digitalPublicKey,
          digitalSignatureAlgorithm: activeAdmin.digitalSignatureAlgorithm,
          digitalSignatureCreatedAt: activeAdmin.digitalSignatureCreatedAt,
          digitalSignatureKeyVersion: activeAdmin.digitalSignatureKeyVersion,
        );

        final int index = registeredUsers.indexWhere((u) => _isAdminUser(u));

        if (index == -1) {
          registeredUsers.insert(0, safeAdmin);
        } else {
          registeredUsers[index] = safeAdmin;
        }

        await saveUsersList();
      }

      final bool clientsSynced = await syncClientsFromCloud();

      return clientsSynced;
    } catch (e) {
      debugPrint('⚠️ [Admin Sync] $e');

      return false;
    }
  }

  // ============================================================
  // FETCH ADMIN
  // ============================================================

  static Future<UserModel?> _fetchAdminFromCloud() async {
    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',
          'input': adminUser.guardianMoxId ?? '',
          'password': '',
          'isMoxId': 'true',
        },
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || _isHtmlResponse(response.body)) {
        return null;
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

      if (map['status'] != 'success' || map['user'] is! Map) {
        return null;
      }

      return UserModel.fromJson(
        _normalizeUserMap(Map<String, dynamic>.from(map['user'])),
      );
    } catch (e) {
      debugPrint('⚠️ [Fetch Admin] $e');

      return null;
    }
  }

  // ============================================================
  // ACTIVATE STORE
  // ============================================================

  static Future<UserModel?> activateStore({
    required UserModel user,
    required String activationKey,
  }) async {
    final String cleanKey = activationKey.trim();

    if (cleanKey.isEmpty) {
      throw Exception('أدخل مفتاح التنشيط.');
    }

    if (!_isValidMoxId(user.moxId)) {
      throw Exception('معرف المتجر غير صالح.');
    }

    final String existingPublishDate = _clean(user.storePublishDate);

    if (existingPublishDate.isNotEmpty &&
        existingPublishDate.toLowerCase() != 'null') {
      throw Exception('هذا المتجر تم تنشيطه مسبقاً.');
    }

    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': _activationAction,
          'moxId': user.moxId.trim(),
          'phone': user.phone.trim(),
          'activationKey': cleanKey,
        },
      );

      debugPrint(
        '🔐 [Store Activation] '
        'إرسال طلب التنشيط...',
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('تعذر الاتصال بخدمة التنشيط.');
      }

      if (_isHtmlResponse(response.body)) {
        throw Exception('خدمة التنشيط أعادت استجابة غير صالحة.');
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is! Map) {
        throw Exception('استجابة التنشيط غير صالحة.');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

      final String status = data['status']?.toString().toLowerCase() ?? '';

      if (status != 'success') {
        final String message = _clean(data['message']?.toString());

        throw Exception(
          message.isNotEmpty ? message : 'مفتاح التنشيط غير صالح.',
        );
      }

      String publishDate = _clean(data['storePublishDate']?.toString());

      String activationDate = _clean(data['activationDate']?.toString());

      UserModel activatedUser = user;

      if (data['user'] is Map) {
        try {
          final Map<String, dynamic> rawUser = Map<String, dynamic>.from(
            data['user'],
          );

          final Map<String, dynamic> normalized = _normalizeUserMap(rawUser);

          activatedUser = UserModel.fromJson(normalized);

          publishDate = _clean(activatedUser.storePublishDate);

          activationDate = _clean(activatedUser.activationDate);
        } catch (e) {
          debugPrint(
            '⚠️ [Store Activation] '
            'تعذر قراءة User: $e',
          );
        }
      }

      if (publishDate.isEmpty || publishDate.toLowerCase() == 'null') {
        throw Exception('تم التنشيط ولكن لم يصل تاريخ بداية الاشتراك.');
      }

      activatedUser = activatedUser.copyWith(
        storePublishDate: publishDate,
        activationDate: activationDate.isNotEmpty
            ? activationDate
            : publishDate,
      );

      final int index = registeredUsers.indexWhere(
        (u) => u.moxId == activatedUser.moxId || u.phone == activatedUser.phone,
      );

      if (index == -1) {
        registeredUsers.add(activatedUser);
      } else {
        registeredUsers[index] = activatedUser;
      }

      _ensureAdmin();

      await saveUsersList();

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(activatedUser.toJson()));

      debugPrint(
        '✅ [Store Activation] '
        'تم تنشيط المتجر لمدة '
        '$storeSubscriptionDays يوم.',
      );

      return activatedUser;
    } catch (e) {
      debugPrint('❌ [Store Activation] $e');

      rethrow;
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

    final String cleanInput = input.trim();

    final String cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // المدير
    // ----------------------------------------------------------

    final bool isAdminLogin = _isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      guardianMoxId: isMoxId ? cleanInput : null,
    );

    if (isAdminLogin) {
      debugPrint(
        '👑 [Admin Login] '
        'تم التعرف على المدير.',
      );

      // --------------------------------------------------------
      // تعديل هنا: انتظار المزامنة بالكامل وجلب العملاء قبل السماح بفتح لوحة المدير
      // --------------------------------------------------------

      await syncAdminData();

      return adminUser;
    }

    // ----------------------------------------------------------
    // Local Login
    // ----------------------------------------------------------

    try {
      final UserModel foundUser = registeredUsers.firstWhere(
        (u) =>
            (isMoxId
                ? (u.guardianMoxId?.trim() == cleanInput ||
                      u.guardianMoxIdCustomer?.trim() == cleanInput)
                : u.phone.trim() == cleanInput) &&
            u.password == cleanPassword,
      );

      return foundUser;
    } catch (_) {}

    // ----------------------------------------------------------
    // Cloud Login
    // ----------------------------------------------------------

    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',
          'input': cleanInput,
          'password': cleanPassword,
          'isMoxId': isMoxId.toString(),
        },
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      if (_isHtmlResponse(response.body)) {
        return null;
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

      if (map['status'] != 'success') {
        return null;
      }

      final dynamic rawUser = map['user'];

      if (rawUser is! Map) {
        return null;
      }

      final UserModel cloudUser = UserModel.fromJson(
        _normalizeUserMap(Map<String, dynamic>.from(rawUser)),
      );

      // --------------------------------------------------------
      // Cloud Admin
      // --------------------------------------------------------

      if (_isAdminUser(cloudUser)) {
        final UserModel safeAdmin = adminUser.copyWith(
          name: cloudUser.name,
          address: cloudUser.address,
          balance: cloudUser.balance,
          commission: cloudUser.commission,
          role: cloudUser.role,
          guardianMoxId: cloudUser.guardianMoxId,
          guardianMoxIdCustomer: cloudUser.guardianMoxIdCustomer,
          points: cloudUser.points,
          myAssets: cloudUser.myAssets,
          storeDescription: cloudUser.storeDescription,
          storePublishDate: cloudUser.storePublishDate,
          activationDate: cloudUser.activationDate,
          digitalPublicKey: cloudUser.digitalPublicKey,
          digitalSignatureAlgorithm: cloudUser.digitalSignatureAlgorithm,
          digitalSignatureCreatedAt: cloudUser.digitalSignatureCreatedAt,
          digitalSignatureKeyVersion: cloudUser.digitalSignatureKeyVersion,
        );

        final int index = registeredUsers.indexWhere((u) => _isAdminUser(u));

        if (index == -1) {
          registeredUsers.insert(0, safeAdmin);
        } else {
          registeredUsers[index] = safeAdmin;
        }

        await saveUsersList();

        await syncClientsFromCloud();

        return safeAdmin;
      }

      // --------------------------------------------------------
      // Normal Cloud User
      // --------------------------------------------------------

      final int index = registeredUsers.indexWhere(
        (u) =>
            u.phone == cloudUser.phone ||
            u.moxId == cloudUser.moxId ||
            (u.guardianMoxId != null &&
                u.guardianMoxId == cloudUser.guardianMoxId),
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
      debugPrint('❌ [Cloud Login] $e');

      return null;
    }
  }

  // ============================================================
  // AUTHENTICATE SYNC
  // ============================================================

  static UserModel? authenticate(String input, String password, bool isMoxId) {
    final String cleanInput = input.trim();

    final String cleanPassword = password.trim();

    if (_isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      guardianMoxId: isMoxId ? cleanInput : null,
    )) {
      return adminUser;
    }

    try {
      return registeredUsers.firstWhere(
        (u) =>
            (isMoxId
                ? (u.guardianMoxId?.trim() == cleanInput ||
                      u.guardianMoxIdCustomer?.trim() == cleanInput)
                : u.phone.trim() == cleanInput) &&
            u.password == cleanPassword,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET USER BY MOX ID / GUARDIAN
  // ============================================================

  static Future<UserModel?> getUserByMoxId(String identifier) async {
    final String cleanIdentifier = identifier.trim().toUpperCase();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    try {
      final Uri uri = Uri.parse(
        _vercelStoreUrl,
      ).replace(queryParameters: {'guardianMoxId': cleanIdentifier});

      debugPrint('🌐 [Public Store] GET $uri');

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '🌐 [Public Store] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        if (_isHtmlResponse(response.body)) {
          debugPrint(
            '⚠️ [Public Store] '
            'الاستجابة HTML.',
          );
        } else {
          final dynamic decoded = json.decode(response.body);

          if (decoded is Map) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              decoded,
            );

            Map<String, dynamic>? rawUser;

            if (data['user'] is Map) {
              rawUser = Map<String, dynamic>.from(data['user']);
            } else if (data['data'] is Map) {
              rawUser = Map<String, dynamic>.from(data['data']);
            } else if (data.containsKey('phone') ||
                data.containsKey('moxId') ||
                data.containsKey('MOXID')) {
              rawUser = data;
            }

            if (rawUser != null) {
              final Map<String, dynamic> normalized = _normalizeUserMap(
                rawUser,
              );

              final UserModel cloudUser = UserModel.fromJson(normalized);

              if (_isValidMoxId(cloudUser.moxId)) {
                if (!_isAdminUser(cloudUser)) {
                  final int index = registeredUsers.indexWhere(
                    (u) =>
                        u.moxId == cloudUser.moxId ||
                        u.phone == cloudUser.phone,
                  );

                  if (index == -1) {
                    registeredUsers.add(cloudUser);
                  } else {
                    registeredUsers[index] = cloudUser;
                  }

                  _ensureAdmin();

                  await saveUsersList();
                }

                return cloudUser;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Public Store Exception] $e');
    }

    try {
      await ensureLoaded();

      for (final UserModel user in registeredUsers) {
        final String moxId = user.moxId.trim().toUpperCase();

        final String phone = user.phone.trim().toUpperCase();

        final String guardianMoxId = _clean(user.guardianMoxId).toUpperCase();

        final String guardianMoxIdCustomer = _clean(
          user.guardianMoxIdCustomer,
        ).toUpperCase();

        if (moxId == cleanIdentifier ||
            phone == cleanIdentifier ||
            guardianMoxId == cleanIdentifier ||
            guardianMoxIdCustomer == cleanIdentifier) {
          return user;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Local Public User] $e');
    }

    return null;
  }

  // ============================================================
  // GET USER BY GUARDIAN MOX ID
  // ============================================================

  static Future<UserModel?> getUserByGuardianMoxId(String guardianMoxId) async {
    return getUserByMoxId(guardianMoxId);
  }
}
