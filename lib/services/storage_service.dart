// ignore_for_file: unused_element

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

  // مهم:
  // لا نرفع هذا الرقم لمجرد تحديث التطبيق بطريقة تؤدي لمسح العملاء.
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

  static String _upper(String? value) {
    return _clean(value).toUpperCase();
  }

  // ============================================================
  // IDENTIFY GUARDIAN MOX ID
  // ============================================================

  static bool _looksLikeGuardianMoxId(String value) {
    final String id = value.trim().toUpperCase();

    if (id.isEmpty) {
      return false;
    }

    // الصيغة الحالية للـ Guardian MOX ID
    // مثال:
    // MOX249-00010001
    //
    // ولا نعتمد على moxId العادي.
    return id.startsWith('MOX');
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

    setIfFound('guardianMoxId', [
      'guardianMoxId',
      'guardianmoxid',
      'guardian_mox_id',
    ]);

    setIfFound('guardianMoxIdCustomer', [
      'guardianMoxIdCustomer',
      'guardianmoxidcustomer',
      'guardian_mox_id_customer',
    ]);

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
    // myAssets إذا وصلت كنص JSON
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
  //
  // هذا للاعتراف بأن UserModel هو المدير.
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

  // ============================================================
  // ADMIN LOGIN IDENTITY
  //
  // مهم:
  // دخول المدير من شاشة الدخول يكون بالـ guardianMoxId فقط.
  // ============================================================

  static bool _isAdminGuardianLogin(String input) {
    final String cleanInput = input.trim().toUpperCase();

    final String adminGuardian = _clean(adminUser.guardianMoxId).toUpperCase();

    return cleanInput.isNotEmpty && cleanInput == adminGuardian;
  }

  static bool _isAdminUser(UserModel user) {
    return _isAdminIdentity(
      phone: user.phone,
      guardianMoxId: user.guardianMoxId,
    );
  }

  // ============================================================
  // LOCAL USER MATCH
  //
  // العميل يمكنه الدخول بواسطة:
  // 1. الهاتف
  // 2. guardianMoxId
  // ============================================================

  static bool _matchesClientIdentifier({
    required UserModel user,
    required String input,
  }) {
    final String cleanInput = input.trim().toUpperCase();

    if (cleanInput.isEmpty) {
      return false;
    }

    final String phone = user.phone.trim().toUpperCase();

    final String guardianMoxId = _clean(user.guardianMoxId).toUpperCase();

    final String guardianMoxIdCustomer = _clean(
      user.guardianMoxIdCustomer,
    ).toUpperCase();

    return phone == cleanInput ||
        guardianMoxId == cleanInput ||
        guardianMoxIdCustomer == cleanInput;
  }

  // ============================================================
  // LOAD USERS
  //
  // مهم جداً:
  // لا يتم حذف saved_users عند تحديث التطبيق.
  //
  // Local Cache = Cache فقط.
  // Cloud = المصدر الأساسي للبيانات.
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

                // المدير محفوظ حتى لو لم يكن
                // لديه moxId عادي صالح.
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
  // لا نحذف العملاء.
  //
  // الإصدار الجديد فقط يضمن وجود version marker.
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
        'ترقية مخزن العملاء من '
        '$savedVersion إلى '
        '$currentLocalUsersVersion',
      );

      // ========================================================
      // مهم جداً:
      // لا نحذف savedUsersKey.
      // ========================================================

      final String? existingData = prefs.getString(savedUsersKey);

      if (existingData != null && existingData.trim().isNotEmpty) {
        debugPrint(
          '✅ [Local Migration] '
          'تم الحفاظ على بيانات العملاء المحلية.',
        );
      }

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);
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
  // يستخدم للمدير فقط.
  // ============================================================

  static Future<void> _syncFromCloudInBackground() async {
    if (_cloudSyncRunning) {
      return;
    }

    _cloudSyncRunning = true;

    try {
      final List<UserModel>? cloudUsers = await _fetchAllUsersFromCloud();

      if (cloudUsers == null) {
        debugPrint(
          '⚠️ [Cloud Sync] '
          'فشلت المزامنة، سيتم استخدام Local Cache.',
        );

        return;
      }

      final List<UserModel> syncedUsers = [];

      for (final UserModel cloudUser in cloudUsers) {
        if (_isAdminUser(cloudUser)) {
          continue;
        }

        if (!_isValidMoxId(cloudUser.moxId)) {
          continue;
        }

        syncedUsers.add(cloudUser);
      }

      // ========================================================
      // لا نستبدل القائمة بشكل أعمى.
      // ندمج السحابة مع المحلي.
      // ========================================================

      final Map<String, UserModel> merged = {};

      for (final UserModel user in registeredUsers) {
        final String key = _userStorageKey(user);

        if (key.isNotEmpty) {
          merged[key] = user;
        }
      }

      for (final UserModel user in syncedUsers) {
        final String key = _userStorageKey(user);

        if (key.isNotEmpty) {
          merged[key] = user;
        }
      }

      registeredUsers = merged.values.toList();

      _ensureAdmin();

      await saveUsersList();

      debugPrint(
        '☁️ [Cloud Sync] '
        'تم تحديث العملاء من السحابة: '
        '${syncedUsers.length} مستخدم.',
      );
    } catch (e) {
      debugPrint('❌ [Cloud Sync] $e');
    } finally {
      _cloudSyncRunning = false;
    }
  }

  // ============================================================
  // USER STORAGE KEY
  // ============================================================

  static String _userStorageKey(UserModel user) {
    final String moxId = _clean(user.moxId).toUpperCase();

    if (moxId.isNotEmpty) {
      return 'mox:$moxId';
    }

    final String guardian = _clean(user.guardianMoxId).toUpperCase();

    if (guardian.isNotEmpty) {
      return 'guardian:$guardian';
    }

    final String phone = _clean(user.phone);

    if (phone.isNotEmpty) {
      return 'phone:$phone';
    }

    return '';
  }

  // ============================================================
  // FETCH ALL USERS
  //
  // إداري فقط.
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromCloud() async {
    try {
      final Uri uri = Uri.parse(
        _vercelStoreUrl,
      ).replace(queryParameters: {'action': 'getAll'});

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '☁️ [Vercel GetAll] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '❌ [Vercel GetAll] '
          'HTTP Error: ${response.body}',
        );

        return null;
      }

      if (_isHtmlResponse(response.body)) {
        debugPrint(
          '❌ [Vercel GetAll] '
          'السيرفر أعاد HTML وليس JSON.',
        );

        return null;
      }

      final dynamic decoded = json.decode(response.body);

      List<dynamic> rawUsers = [];

      if (decoded is Map && decoded['users'] is List) {
        rawUsers = List<dynamic>.from(decoded['users']);
      } else if (decoded is List) {
        rawUsers = List<dynamic>.from(decoded);
      } else {
        debugPrint(
          '❌ [Vercel GetAll] '
          'الاستجابة لا تحتوي على قائمة مستخدمين.',
        );

        return null;
      }

      final List<UserModel> cloudUsers = [];

      for (final dynamic item in rawUsers) {
        if (item is! Map) {
          continue;
        }

        try {
          final Map<String, dynamic> mapItem = _normalizeUserMap(
            Map<String, dynamic>.from(item),
          );

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
          debugPrint(
            '⚠️ [Cloud User Parse] '
            'تخطي سجل غير صالح: $e',
          );
        }
      }

      debugPrint(
        '✅ [Vercel GetAll] '
        'تم تحليل '
        '${cloudUsers.length} مستخدم.',
      );

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

      debugPrint(
        '🔐 [Store Activation] '
        'HTTP ${response.statusCode}',
      );

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
        'تم حفظ ${jsonList.length} مستخدم.',
      );
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
    final UserModel? existingLocalUser = _findLocalUser(user);

    final bool isNewUser =
        existingLocalUser == null || _clean(existingLocalUser.password).isEmpty;

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

      // ========================================================
      // كلمة السر:
      // ترسل عند إنشاء مستخدم جديد فقط.
      // ========================================================
      'password': isNewUser ? user.password : '',

      // ========================================================
      // الاشتراك
      // ========================================================
      'storePublishDate': user.storePublishDate ?? '',

      'activationDate': user.activationDate ?? '',

      // ========================================================
      // التوقيع الرقمي
      // ========================================================
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
        '⚠️ [Add User] '
        'فشل الحفظ السحابي، '
        'سيتم الاحتفاظ بالنسخة المحلية.',
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
  // FIND LOCAL USER
  // ============================================================

  static UserModel? _findLocalUser(UserModel user) {
    try {
      return registeredUsers.firstWhere(
        (u) =>
            u.moxId == user.moxId ||
            u.phone == user.phone ||
            _upper(u.guardianMoxId) == _upper(user.guardianMoxId),
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
  // SAVE TO CLOUD
  // ============================================================

  static Future<bool> _saveToCloud(UserModel user) async {
    try {
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '☁️ [Cloud Save] '
        'HTTP ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '❌ [Cloud Save] '
          'HTTP Error: ${response.body}',
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
        final UserModel user = UserModel.fromJson(_normalizeUserMap(data));

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

    // ==========================================================
    // لا نحذف المدير.
    // ==========================================================

    final UserModel? localAdmin = registeredUsers.cast<UserModel?>().firstWhere(
      (u) => u != null && _isAdminUser(u),
      orElse: () => null,
    );

    registeredUsers = users;

    if (localAdmin != null) {
      registeredUsers.insert(0, localAdmin);
    }

    _ensureAdmin();

    _isLoaded = true;

    await saveUsersList();
  }

  // ============================================================
  // ADMIN + CLIENT CLOUD SYNC
  // ============================================================

  static Future<void> _syncAdminAndClientsInBackground(
    String cleanInput,
    String cleanPassword,
  ) async {
    try {
      // ========================================================
      // 1. تحديث بيانات المدير
      // ========================================================

      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',
          'input': cleanInput,
          'password': cleanPassword,
          'isMoxId': 'true',
        },
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && !_isHtmlResponse(response.body)) {
        final dynamic decoded = json.decode(response.body);

        if (decoded is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

          if (map['status'] == 'success' && map['user'] is Map) {
            final UserModel cloudAdmin = UserModel.fromJson(
              _normalizeUserMap(Map<String, dynamic>.from(map['user'])),
            );

            // ==================================================
            // لا نسمح بتغيير هوية المدير
            // من بيانات السحابة.
            // ==================================================

            final UserModel safeAdmin = adminUser.copyWith(
              name: cloudAdmin.name,
              address: cloudAdmin.address,
              balance: cloudAdmin.balance,
              commission: cloudAdmin.commission,
              role: cloudAdmin.role,
              guardianMoxId: cloudAdmin.guardianMoxId,
              guardianMoxIdCustomer: cloudAdmin.guardianMoxIdCustomer,
              points: cloudAdmin.points,
              myAssets: cloudAdmin.myAssets,
              storeDescription: cloudAdmin.storeDescription,
              storePublishDate: cloudAdmin.storePublishDate,
              activationDate: cloudAdmin.activationDate,
              digitalPublicKey: cloudAdmin.digitalPublicKey,
              digitalSignatureAlgorithm: cloudAdmin.digitalSignatureAlgorithm,
              digitalSignatureCreatedAt: cloudAdmin.digitalSignatureCreatedAt,
              digitalSignatureKeyVersion: cloudAdmin.digitalSignatureKeyVersion,
            );

            final int index = registeredUsers.indexWhere(
              (u) => _isAdminUser(u),
            );

            if (index == -1) {
              registeredUsers.insert(0, safeAdmin);
            } else {
              registeredUsers[index] = safeAdmin;
            }

            await saveUsersList();

            debugPrint(
              '✅ [Admin Sync] '
              'تم تحديث بيانات المدير.',
            );
          }
        }
      }

      // ========================================================
      // 2. جلب جميع العملاء
      // ========================================================

      await _syncFromCloudInBackground();

      debugPrint(
        '✅ [Admin Sync] '
        'تمت مزامنة المدير والعملاء.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [Admin Sync Background Error] '
        '$e',
      );
    }
  }

  // ============================================================
  // CLOUD LOGIN REQUEST
  // ============================================================

  static Future<UserModel?> _cloudLoginRequest({
    required String input,
    required String password,
    required bool isMoxId,
  }) async {
    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',
          'input': input,
          'password': password,
          'isMoxId': isMoxId.toString(),
        },
      );

      debugPrint(
        '🌐 [Cloud Login] '
        'isMoxId=$isMoxId',
      );

      final http.Response response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '🌐 [Cloud Login] '
        'HTTP ${response.statusCode}',
      );

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

      return UserModel.fromJson(
        _normalizeUserMap(Map<String, dynamic>.from(rawUser)),
      );
    } catch (e) {
      debugPrint(
        '⚠️ [Cloud Login Request] '
        '$e',
      );

      return null;
    }
  }

  // ============================================================
  // AUTHENTICATE ASYNC
  //
  // القواعد:
  //
  // المدير:
  // guardianMoxId فقط.
  //
  // العميل:
  // phone أو guardianMoxId.
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

    final String upperInput = cleanInput.toUpperCase();

    // ==========================================================
    // 1. المدير
    //
    // لا نعتمد على phone هنا.
    // المدير يدخل بالـ guardianMoxId.
    // ==========================================================

    final bool adminLogin = _isAdminGuardianLogin(cleanInput);

    if (adminLogin) {
      debugPrint(
        '👑 [Admin Login] '
        'الدخول بواسطة guardianMoxId.',
      );

      // ========================================================
      // نتحقق من كلمة السر مع Google.
      // لكن لا نمنع الدخول بسبب Cache.
      // ========================================================

      final UserModel? cloudAdmin = await _cloudLoginRequest(
        input: cleanInput,
        password: cleanPassword,
        isMoxId: true,
      );

      if (cloudAdmin != null && !_isAdminUser(cloudAdmin)) {
        debugPrint(
          '❌ [Admin Login] '
          'الاستجابة ليست حساب المدير.',
        );

        return null;
      }

      if (cloudAdmin == null) {
        debugPrint(
          '⚠️ [Admin Login] '
          'تعذر التحقق السحابي من المدير.',
        );

        // لا نسمح بكلمة سر فارغة.
        // ولا نعرف كلمة سر المدير من الكود.
        //
        // لذلك لا ندخل المدير محلياً إلا إذا
        // كان هناك نظام تحقق آخر في طبقة أعلى.
        //
        // في النسخة الحالية، Google هو صاحب قرار
        // كلمة سر المدير.
        return null;
      }

      // ========================================================
      // مزامنة المدير والعملاء قبل العودة للوحة.
      // ========================================================

      await _syncAdminAndClientsInBackground(cleanInput, cleanPassword);

      final UserModel currentAdmin = registeredUsers.firstWhere(
        (u) => _isAdminUser(u),
        orElse: () => adminUser,
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(currentAdmin.toJson()));

      return currentAdmin;
    }

    // ==========================================================
    // 2. العميل
    //
    // يقبل الهاتف أو guardianMoxId.
    //
    // لا نعتمد فقط على isMoxId القادمة من الشاشة.
    // ==========================================================

    try {
      final UserModel foundUser = registeredUsers.firstWhere(
        (u) =>
            !_isAdminUser(u) &&
            _matchesClientIdentifier(user: u, input: cleanInput) &&
            u.password == cleanPassword,
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(foundUser.toJson()));

      return foundUser;
    } catch (_) {}

    // ==========================================================
    // 3. Cloud Login
    //
    // إذا بدأ بـ MOX نعتبره guardianMoxId.
    // غير ذلك نجرب الهاتف.
    // ==========================================================

    final bool detectedMoxId = isMoxId || _looksLikeGuardianMoxId(upperInput);

    UserModel? cloudUser = await _cloudLoginRequest(
      input: cleanInput,
      password: cleanPassword,
      isMoxId: detectedMoxId,
    );

    // ==========================================================
    // إذا فشلت المحاولة الأولى:
    //
    // نجرب الهوية الأخرى.
    //
    // هذا يجعل StorageService لا يعتمد على خطأ
    // اختيار الشاشة بين phone / guardianMoxId.
    // ==========================================================

    cloudUser ??= await _cloudLoginRequest(
      input: cleanInput,
      password: cleanPassword,
      isMoxId: !detectedMoxId,
    );

    if (cloudUser == null) {
      debugPrint(
        '❌ [Cloud Login] '
        'لم يتم العثور على العميل.',
      );

      return null;
    }

    // ==========================================================
    // منع استخدام بيانات المدير من مسار العميل.
    // ==========================================================

    if (_isAdminUser(cloudUser)) {
      debugPrint(
        '❌ [Client Login] '
        'تم رفض تسجيل المدير من مسار العميل.',
      );

      return null;
    }

    if (!_isValidMoxId(cloudUser.moxId)) {
      debugPrint(
        '❌ [Client Login] '
        'العميل لا يملك MoxId صالح.',
      );

      return null;
    }

    // ==========================================================
    // تحديث Local Cache
    // ==========================================================

    final int index = registeredUsers.indexWhere(
      (u) =>
          u.moxId == cloudUser!.moxId ||
          u.phone == cloudUser.phone ||
          _upper(u.guardianMoxId) == _upper(cloudUser.guardianMoxId),
    );

    if (index == -1) {
      registeredUsers.add(cloudUser);
    } else {
      registeredUsers[index] = cloudUser;
    }

    _ensureAdmin();

    await saveUsersList();

    // ==========================================================
    // حفظ الجلسة
    // ==========================================================

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(userKey, jsonEncode(cloudUser.toJson()));

    debugPrint(
      '✅ [Client Login] '
      'تم دخول العميل بواسطة '
      '${detectedMoxId ? 'guardianMoxId' : 'phone'}.',
    );

    return cloudUser;
  }

  // ============================================================
  // AUTHENTICATE SYNC
  //
  // تستخدم فقط للكاش المحلي.
  //
  // العميل:
  // phone أو guardianMoxId.
  //
  // المدير:
  // لا يسمح له بالدخول عبر هذه الدالة.
  // ============================================================

  static UserModel? authenticate(String input, String password, bool isMoxId) {
    final String cleanInput = input.trim();

    final String cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    // المدير لا يدخل عبر authenticate sync.
    if (_isAdminGuardianLogin(cleanInput)) {
      return null;
    }

    try {
      return registeredUsers.firstWhere(
        (u) =>
            !_isAdminUser(u) &&
            _matchesClientIdentifier(user: u, input: cleanInput) &&
            u.password == cleanPassword,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // PUBLIC USER
  //
  // يعتمد على guardianMoxId.
  //
  // لا يستخدم getAll.
  // ============================================================

  static Future<UserModel?> getUserByMoxId(String identifier) async {
    final String cleanIdentifier = identifier.trim().toUpperCase();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    // ==========================================================
    // Vercel
    // ==========================================================

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

          debugPrint(
            '🌐 [RAW VERCEL RESPONSE]: '
            '${response.body}',
          );

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
              final Map<String, dynamic> userMap = _normalizeUserMap(rawUser);

              // =================================================
              // guardianMoxId
              // =================================================

              final String guardian = _clean(
                userMap['guardianMoxId']?.toString(),
              );

              if (!_isValidGuardianMoxId(guardian)) {
                debugPrint(
                  '⚠️ [Public Store] '
                  'guardianMoxId غير صالح.',
                );
              } else {
                // =================================================
                // storePublishDate
                // =================================================

                final String pubDate = _clean(
                  userMap['storePublishDate']?.toString(),
                );

                if (pubDate.isNotEmpty && pubDate.toLowerCase() != 'null') {
                  userMap['storePublishDate'] = pubDate;
                }

                // =================================================
                // myAssets
                // =================================================

                final dynamic assets = userMap['myAssets'];

                if (assets is String && assets.trim().isNotEmpty) {
                  try {
                    final dynamic decodedAssets = json.decode(assets);

                    if (decodedAssets is List) {
                      userMap['myAssets'] = decodedAssets;
                    }
                  } catch (_) {
                    final List<String> splitAssets = assets
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    userMap['myAssets'] = splitAssets;
                  }
                }

                final UserModel cloudUser = UserModel.fromJson(userMap);

                if (_isValidMoxId(cloudUser.moxId)) {
                  if (!_isAdminUser(cloudUser)) {
                    final int index = registeredUsers.indexWhere(
                      (u) =>
                          u.moxId == cloudUser.moxId ||
                          u.phone == cloudUser.phone ||
                          _upper(u.guardianMoxId) ==
                              _upper(cloudUser.guardianMoxId),
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

            debugPrint(
              '⚠️ [Public Store] '
              'لم يتم العثور على المستخدم.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Public Store Exception] $e');
    }

    // ==========================================================
    // Local Fallback
    //
    // لا نستخدم moxId كرابط عام.
    // guardianMoxId هو الأساس.
    // ==========================================================

    try {
      await ensureLoaded();

      for (final UserModel user in registeredUsers) {
        final String guardianMoxId = _clean(user.guardianMoxId).toUpperCase();

        final String guardianMoxIdCustomer = _clean(
          user.guardianMoxIdCustomer,
        ).toUpperCase();

        if (guardianMoxId == cleanIdentifier ||
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
