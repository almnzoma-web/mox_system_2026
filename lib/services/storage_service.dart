import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../models/marketing_card.dart';

class StorageService {
  // ============================================================
  // LOCAL KEYS
  // ============================================================

  static const String userKey = 'current_mox_user';

  static const String savedUsersKey = 'saved_users';

  static const String localUsersVersionKey = 'mox_local_users_version';

  static const int currentLocalUsersVersion = 2;

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
      'https://script.google.com/macros/s/AKfycbzl7NumkBE1qGI8SiVRA2TrH7Z5X_3ixp0YIAXirErmPl0hqV020h1VWyGC-4ijqSIJ/exec';

  // ============================================================
  // VERCEL STORE API
  // ============================================================

  static const String _vercelStoreUrl = 'https://mox-2026.vercel.app/api/store';

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
        id.toLowerCase() != 'لم يحدد';
  }

  // ============================================================
  // GUARDIAN VALIDATION
  // ============================================================

  // ignore: unused_element
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

  static bool _isAdminIdentity({String? phone, String? moxId}) {
    final String cleanPhone = _clean(phone);

    final String cleanMoxId = _clean(moxId);

    return cleanPhone == adminUser.phone || cleanMoxId == adminUser.moxId;
  }

  static bool _isAdminUser(UserModel user) {
    return _isAdminIdentity(phone: user.phone, moxId: user.moxId);
  }

  // ============================================================
  // LOAD USERS
  //
  // مهم:
  // لا يوجد getAll هنا.
  //
  // المتجر العام Silver لا يحتاج تحميل كل العملاء.
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
                final UserModel user = UserModel.fromJson(
                  Map<String, dynamic>.from(item),
                );

                if (!_isValidMoxId(user.moxId)) {
                  continue;
                }

                localUsers.add(user);
              } catch (e) {
                debugPrint('⚠️ [Local User Parse] تخطي مستخدم: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ [Local JSON] بيانات المستخدمين تالفة: $e');
        }
      }

      registeredUsers = localUsers;

      _ensureAdmin();

      _isLoaded = true;

      // ========================================================
      // لا تعمل مزامنة getAll تلقائياً هنا.
      // ========================================================

      debugPrint(
        '✅ [BOOT] Local users loaded: '
        '${registeredUsers.length}',
      );
    } catch (e) {
      debugPrint('❌ [Hybrid Local] خطأ في التحميل المحلي: $e');

      registeredUsers = [adminUser];

      _isLoaded = true;
    }
  }

  // ============================================================
  // LOCAL MEMORY MIGRATION
  // ============================================================

  static Future<void> _migrateLocalUsersIfNeeded(
    SharedPreferences prefs,
  ) async {
    try {
      final int savedVersion = prefs.getInt(localUsersVersionKey) ?? 0;

      if (savedVersion >= currentLocalUsersVersion) {
        return;
      }

      debugPrint('🧹 [Local Migration] تنظيف ذاكرة العملاء القديمة...');

      await prefs.remove(savedUsersKey);

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      debugPrint('✅ [Local Migration] تم تنظيف ذاكرة العملاء.');
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
  // CLOUD SYNC
  //
  // هذه الوظيفة أصبحت اختيارية.
  // لا يتم تشغيلها أثناء فتح المتجر العام.
  // ============================================================

  // ignore: unused_element
  static Future<void> _syncFromCloudInBackground() async {
    if (_cloudSyncRunning) {
      return;
    }

    _cloudSyncRunning = true;

    try {
      final List<UserModel>? cloudUsers = await _fetchAllUsersFromCloud();

      if (cloudUsers == null) {
        debugPrint(
          '⚠️ [Cloud Sync] لم تنجح المزامنة، سيتم استخدام Local Cache.',
        );

        return;
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

      await saveUsersList();

      debugPrint(
        '☁️ [Cloud Sync] تم تحديث العملاء من Google Sheets: '
        '${registeredUsers.length} مستخدم.',
      );
    } catch (e) {
      debugPrint('❌ [Cloud Sync] $e');
    } finally {
      _cloudSyncRunning = false;
    }
  }

  // ============================================================
  // FETCH ALL USERS
  //
  // يستخدم فقط للعمليات التي تحتاج كل العملاء.
  // ليس للمتجر العام.
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromCloud() async {
    try {
      final Uri uri = Uri.parse(
        _vercelStoreUrl,
      ).replace(queryParameters: {'action': 'getAll'});

      final http.Response response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('☁️ [Vercel GetAll] HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ [Vercel GetAll] HTTP Error: ${response.body}');

        return null;
      }

      if (_isHtmlResponse(response.body)) {
        debugPrint('❌ [Vercel GetAll] السيرفر أعاد HTML وليس JSON.');

        return null;
      }

      final dynamic decoded = json.decode(response.body);

      List<dynamic> rawUsers = [];

      // ----------------------------------------------------------
      // Vercel يرجع users عندما تكون الاستجابة List من Google
      // ----------------------------------------------------------

      if (decoded is Map && decoded['users'] is List) {
        rawUsers = List<dynamic>.from(decoded['users']);
      }
      // ----------------------------------------------------------
      // احتياط إذا أعاد API قائمة مباشرة
      // ----------------------------------------------------------
      else if (decoded is List) {
        rawUsers = List<dynamic>.from(decoded);
      } else {
        debugPrint('❌ [Vercel GetAll] الاستجابة لا تحتوي على قائمة مستخدمين.');

        return null;
      }

      final List<UserModel> cloudUsers = [];

      for (final dynamic item in rawUsers) {
        if (item is! Map) {
          continue;
        }

        try {
          final Map<String, dynamic> mapItem = Map<String, dynamic>.from(item);

          if ((!mapItem.containsKey('moxId') ||
                  _clean(mapItem['moxId']?.toString()).isEmpty) &&
              mapItem.containsKey('MOXID')) {
            mapItem['moxId'] = mapItem['MOXID'];
          }

          final UserModel cloudUser = UserModel.fromJson(mapItem);

          if (!_isValidMoxId(cloudUser.moxId)) {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint('⚠️ [Cloud User Parse] تخطي سجل غير صالح: $e');
        }
      }

      debugPrint('✅ [Vercel GetAll] تم تحليل ${cloudUsers.length} مستخدم.');

      return cloudUsers;
    } catch (e) {
      debugPrint('❌ [Vercel GetAll Exception] $e');

      return null;
    }
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
      'storePublishDate': user.storePublishDate ?? '',
      'activationDate': user.activationDate ?? '',
      'digitalPublicKey': user.digitalPublicKey ?? '',
      'digitalSignatureAlgorithm': user.digitalSignatureAlgorithm,
      'digitalSignatureCreatedAt': user.digitalSignatureCreatedAt ?? '',
      'digitalSignatureKeyVersion': user.digitalSignatureKeyVersion.toString(),
    };
  }

  // ============================================================
  // ADD USER
  // ============================================================

  static Future<void> addUser(UserModel newUser) async {
    await ensureLoaded();

    if (!_isValidMoxId(newUser.moxId)) {
      debugPrint('❌ محاولة حفظ مستخدم بدون MoxId تم رفضها.');

      return;
    }

    final bool cloudSaved = await _saveToCloud(newUser);

    if (!cloudSaved) {
      debugPrint(
        '⚠️ [Add User] فشل الحفظ السحابي، سيتم الاحتفاظ بالنسخة المحلية.',
      );
    }

    final int index = registeredUsers.indexWhere(
      (u) => u.moxId == newUser.moxId || u.phone == newUser.phone,
    );

    if (index == -1) {
      registeredUsers.add(newUser);
    } else {
      registeredUsers[index] = newUser;
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

    final bool cloudSaved = await _saveToCloud(user);

    if (!cloudSaved) {
      throw Exception('تعذر حفظ بيانات المتجر في Google Sheet.');
    }

    final int index = registeredUsers.indexWhere(
      (u) => u.moxId == user.moxId || u.phone == user.phone,
    );

    if (index == -1) {
      registeredUsers.add(user);
    } else {
      registeredUsers[index] = user;
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
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      debugPrint('☁️ [Cloud Save] HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ [Cloud Save] HTTP Error: ${response.body}');

        return false;
      }

      if (_isHtmlResponse(response.body)) {
        debugPrint('❌ [Cloud Save] الاستجابة HTML.');

        return false;
      }

      try {
        final dynamic decoded = json.decode(response.body);

        if (decoded is Map) {
          final String status =
              decoded['status']?.toString().toLowerCase() ?? '';

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
      final SharedPreferences prefs = await SharedPreferences.getInstance();

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
        final UserModel user = UserModel.fromJson(data);

        if (!_isValidMoxId(user.moxId)) {
          continue;
        }

        if (_isAdminUser(user)) {
          continue;
        }

        users.add(user);
      } catch (e) {
        debugPrint('⚠️ [Save Clients Data] تخطي سجل: $e');
      }
    }

    registeredUsers = users;

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

    final String cleanInput = input.trim();

    final String cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    final bool isAdminLogin = _isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      moxId: isMoxId ? cleanInput : null,
    );

    if (!isAdminLogin) {
      try {
        final UserModel foundUser = registeredUsers.firstWhere(
          (u) =>
              (isMoxId
                  ? u.moxId.trim() == cleanInput
                  : u.phone.trim() == cleanInput) &&
              u.password == cleanPassword,
        );

        return foundUser;
      } catch (_) {}
    }

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
          .get(uri)
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
        Map<String, dynamic>.from(rawUser),
      );

      if (_isAdminUser(cloudUser)) {
        final UserModel safeAdmin = adminUser.copyWith(
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

        return safeAdmin;
      }

      if (!_isValidMoxId(cloudUser.moxId)) {
        return null;
      }

      final int index = registeredUsers.indexWhere(
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
  // PUBLIC USER
  //
  // مهم جداً:
  //
  // لا تستخدم getAll.
  //
  // تستخدم Vercel:
  //
  // /api/store?guardianMoxId=...
  //
  // ============================================================

  static Future<UserModel?> getUserByMoxId(String identifier) async {
    final String cleanIdentifier = identifier.trim().toUpperCase();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    // ============================================================
    // 1. إذا كان لدينا Guardian MOX ID
    //    استخدم Vercel مباشرة
    // ============================================================

    try {
      final Uri uri = Uri.parse(
        _vercelStoreUrl,
      ).replace(queryParameters: {'guardianMoxId': cleanIdentifier});

      debugPrint('🌐 [Public Store] GET $uri');

      final http.Response response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('🌐 [Public Store] HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        if (_isHtmlResponse(response.body)) {
          debugPrint('⚠️ [Public Store] الاستجابة HTML.');
        } else {
          final dynamic decoded = json.decode(response.body);

          if (decoded is Map) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              decoded,
            );

            Map<String, dynamic>? rawUser;

            // ------------------------------------------------------
            // الشكل:
            // { user: {...} }
            // ------------------------------------------------------

            if (data['user'] is Map) {
              rawUser = Map<String, dynamic>.from(data['user']);
            }
            // ------------------------------------------------------
            // الشكل:
            // { data: {...} }
            // ------------------------------------------------------
            else if (data['data'] is Map) {
              rawUser = Map<String, dynamic>.from(data['data']);
            }
            // ------------------------------------------------------
            // الشكل:
            // user مباشرة داخل response
            // ------------------------------------------------------
            else if (data.containsKey('phone') ||
                data.containsKey('moxId') ||
                data.containsKey('MOXID')) {
              rawUser = data;
            }

            if (rawUser != null) {
              final Map<String, dynamic> userMap = Map<String, dynamic>.from(
                rawUser,
              );

              if ((!userMap.containsKey('moxId') ||
                      _clean(userMap['moxId']?.toString()).isEmpty) &&
                  userMap.containsKey('MOXID')) {
                userMap['moxId'] = userMap['MOXID'];
              }

              final UserModel cloudUser = UserModel.fromJson(userMap);

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

            // ------------------------------------------------------
            // إذا كان API أعاد success=false
            // ------------------------------------------------------

            debugPrint('⚠️ [Public Store] لم يتم العثور على المستخدم: $data');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Public Store Exception] $e');
    }

    // ============================================================
    // 2. Local Fallback
    // ============================================================

    try {
      await ensureLoaded();

      for (final UserModel user in registeredUsers) {
        final String moxId = user.moxId.trim().toUpperCase();

        final String phone = user.phone.trim().toUpperCase();

        final String guardianMoxId = _clean(
          user.guardianMoxId,
        ).trim().toUpperCase();

        final String guardianMoxIdCustomer = _clean(
          user.guardianMoxIdCustomer,
        ).trim().toUpperCase();

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

  // ============================================================
  // CLIENT CARDS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getClientCards(
    String identifier,
  ) async {
    try {
      final UserModel? user = await getUserByMoxId(identifier);

      if (user != null && user.myAssets.isNotEmpty) {
        return user.myAssets.map((card) => card.toJson()).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [Client Cards] $e');
    }

    return [];
  }

  // ============================================================
  // FORCE CLOUD REFRESH
  //
  // هذه وظيفة إدارية فقط.
  // ============================================================

  static Future<bool> refreshUsersFromCloud() async {
    if (_cloudSyncRunning) {
      return false;
    }

    _cloudSyncRunning = true;

    try {
      final List<UserModel>? cloudUsers = await _fetchAllUsersFromCloud();

      if (cloudUsers == null) {
        return false;
      }

      registeredUsers = [];

      for (final UserModel user in cloudUsers) {
        if (!_isValidMoxId(user.moxId)) {
          continue;
        }

        if (_isAdminUser(user)) {
          continue;
        }

        registeredUsers.add(user);
      }

      _ensureAdmin();

      await saveUsersList();

      return true;
    } catch (e) {
      debugPrint('❌ [Force Cloud Refresh] $e');

      return false;
    } finally {
      _cloudSyncRunning = false;
    }
  }

  // ============================================================
  // CLEAR LOCAL USERS
  // ============================================================

  static Future<void> clearLocalUsers() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.remove(savedUsersKey);

      registeredUsers = [adminUser];

      _isLoaded = true;

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      debugPrint('🧹 [Local Clear] تم حذف جميع العملاء من الذاكرة المحلية.');
    } catch (e) {
      debugPrint('❌ [Local Clear] $e');
    }
  }
}
