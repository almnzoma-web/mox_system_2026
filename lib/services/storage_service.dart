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

  static const String savedUsersBackupKey = 'saved_users_backup';

  static const String localUsersVersionKey = 'mox_local_users_version';

  static const String registrationSequenceKey = 'mox_registration_sequence';

  // ============================================================
  // LOCAL VERSION
  // ============================================================

  static const int currentLocalUsersVersion = 5;

  // ============================================================
  // RUNTIME MEMORY
  // ============================================================

  static List<UserModel> registeredUsers = [];

  static bool _isLoaded = false;

  static bool _cloudSyncRunning = false;

  static bool _registrationSequenceRunning = false;

  // ============================================================
  // GOOGLE APPS SCRIPT
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyjUvfKEcii4ck2klEIgPjSXDzss3AipUV6nHpVlqsoJ7gdhefx_Ua8AdHENIbX8HGg/exec';

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
  // CLEAN
  // ============================================================

  static String _clean(String? value) {
    return value?.trim() ?? '';
  }

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
  // MOX ID VALIDATION
  // ============================================================

  static bool _isValidMoxId(String? value) {
    final String id = _clean(value);

    return id.isNotEmpty &&
        id.toLowerCase() != 'null' &&
        id.toLowerCase() != 'undefined' &&
        id != 'لم يحدد';
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
  // CUSTOMER IDENTITY
  // ============================================================

  static bool _isValidCustomerIdentity(UserModel user) {
    final String phone = _clean(user.phone);

    final String guardian = _clean(user.guardianMoxId);

    final String guardianCustomer = _clean(user.guardianMoxIdCustomer);

    final bool validGuardian =
        _isValidGuardianMoxId(guardian) ||
        _isValidGuardianMoxId(guardianCustomer);

    return phone.isNotEmpty && validGuardian;
  }

  // ============================================================
  // PERSISTABLE USER
  // ============================================================

  static bool _isPersistableUser(UserModel user) {
    return _isAdminUser(user) ||
        _isValidMoxId(user.moxId) ||
        _isValidCustomerIdentity(user);
  }

  // ============================================================
  // ACCOUNT TYPE NORMALIZATION
  // ============================================================

  static String _normalizedAccountType(UserModel user) {
    return _clean(user.accountType).toLowerCase();
  }

  // ============================================================
  // FREE ACCOUNT
  //
  // الحساب المجاني يدخل بواسطة:
  //
  // PHONE + PASSWORD
  //
  // ============================================================

  static bool _isFreeAccount(UserModel user) {
    final String type = _normalizedAccountType(user);

    if (type.isEmpty) {
      return false;
    }

    return type.contains('مجاني') ||
        type.contains('free') ||
        type.contains('basic');
  }

  // ============================================================
  // PROFESSIONAL ACCOUNT
  //
  // الحساب الاحترافي يدخل بواسطة:
  //
  // guardianMoxId + PASSWORD
  //
  // ============================================================

  static bool _isProfessionalAccount(UserModel user) {
    final String type = _normalizedAccountType(user);

    if (type.isEmpty) {
      return false;
    }

    return type.contains('احترافي') ||
        type.contains('professional') ||
        type.contains('pro');
  }

  // ============================================================
  // LOGIN IDENTITY RULE
  // ============================================================
  //
  // القاعدة الجديدة:
  //
  // FREE:
  // phone + password
  //
  // PROFESSIONAL:
  // guardianMoxId + password
  //
  // ============================================================

  static bool _isValidLoginIdentity({
    required UserModel user,
    required bool isMoxId,
    required String input,
  }) {
    final String cleanInput = _clean(input);

    if (cleanInput.isEmpty) {
      return false;
    }

    // ----------------------------------------------------------
    // ADMIN
    // ----------------------------------------------------------

    if (_isAdminUser(user)) {
      return _isAdminIdentity(
        phone: isMoxId ? null : cleanInput,
        guardianMoxId: isMoxId ? cleanInput : null,
      );
    }

    // ----------------------------------------------------------
    // PROFESSIONAL
    //
    // لا يسمح له بالدخول بالهاتف.
    // ----------------------------------------------------------

    if (_isProfessionalAccount(user)) {
      if (!isMoxId) {
        return false;
      }

      final String guardian = _clean(user.guardianMoxId).toUpperCase();

      final String guardianCustomer = _clean(
        user.guardianMoxIdCustomer,
      ).toUpperCase();

      final String loginGuardian = cleanInput.toUpperCase();

      return guardian == loginGuardian || guardianCustomer == loginGuardian;
    }

    // ----------------------------------------------------------
    // FREE
    //
    // لا يسمح له بالدخول بـ guardianMoxId.
    // ----------------------------------------------------------

    if (_isFreeAccount(user)) {
      if (isMoxId) {
        return false;
      }

      return _clean(user.phone) == cleanInput;
    }

    // ----------------------------------------------------------
    // ACCOUNT TYPE UNKNOWN
    //
    // لا نسمح بتسجيل الدخول الرئيسي إذا كان نوع الحساب
    // غير معروف.
    //
    // هذا يمنع فتح ثغرة بسبب بيانات ناقصة.
    // ----------------------------------------------------------

    return false;
  }

  // ============================================================
  // ADMIN IDENTITY
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
      cleanGuardianMoxId: user.guardianMoxIdCustomer,
    );
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

    setIfFound('points', [
      'points',
      'Points',
      'POINTS',
      'user_points',
      'USER_POINTS',
    ]);

    // ----------------------------------------------------------
    // POINTS
    // ----------------------------------------------------------

    if (result['points'] != null) {
      result['points'] =
          int.tryParse(result['points'].toString()) ??
          (result['points'] is double
              ? (result['points'] as double).toInt()
              : 0);
    }

    // ----------------------------------------------------------
    // ASSETS
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
  // LOCAL USER IDENTITY KEY
  // ============================================================

  static String _userIdentityKey(UserModel user) {
    final String moxId = _clean(user.moxId).toUpperCase();

    final String phone = _clean(user.phone);

    final String guardian = _clean(
      user.guardianMoxId ?? user.guardianMoxIdCustomer,
    ).toUpperCase();

    if (moxId.isNotEmpty && moxId != 'NULL' && moxId != 'UNDEFINED') {
      return 'MOX:$moxId';
    }

    if (phone.isNotEmpty && guardian.isNotEmpty) {
      return 'CUSTOMER:$phone:$guardian';
    }

    if (phone.isNotEmpty) {
      return 'PHONE:$phone';
    }

    return 'USER:${user.hashCode}';
  }

  // ============================================================
  // SAME USER
  // ============================================================

  static bool _sameUser(UserModel a, UserModel b) {
    final String aMox = _clean(a.moxId).toUpperCase();

    final String bMox = _clean(b.moxId).toUpperCase();

    // ----------------------------------------------------------
    // MOX ID
    // ----------------------------------------------------------

    if (_isValidMoxId(aMox) && _isValidMoxId(bMox)) {
      return aMox == bMox;
    }

    // ----------------------------------------------------------
    // PHONE
    // ----------------------------------------------------------

    final String aPhone = _clean(a.phone);

    final String bPhone = _clean(b.phone);

    if (aPhone.isEmpty || bPhone.isEmpty || aPhone != bPhone) {
      return false;
    }

    // ----------------------------------------------------------
    // GUARDIAN
    // ----------------------------------------------------------

    final String aGuardian = _clean(
      a.guardianMoxId ?? a.guardianMoxIdCustomer,
    ).toUpperCase();

    final String bGuardian = _clean(
      b.guardianMoxId ?? b.guardianMoxIdCustomer,
    ).toUpperCase();

    if (aGuardian.isEmpty || bGuardian.isEmpty) {
      return false;
    }

    return aGuardian == bGuardian;
  }

  // ============================================================
  // PRESERVE USER STATE
  // ============================================================

  static UserModel _preserveUserState({
    required UserModel? oldUser,
    required UserModel newUser,
  }) {
    if (oldUser == null) {
      return newUser;
    }

    final String oldPassword = _clean(oldUser.password);

    final String newPassword = _clean(newUser.password);

    final String oldPublishDate = _clean(oldUser.storePublishDate);

    final String oldActivationDate = _clean(oldUser.activationDate);

    final String newPublishDate = _clean(newUser.storePublishDate);

    final String newActivationDate = _clean(newUser.activationDate);

    return newUser.copyWith(
      password: newPassword.isNotEmpty ? newPassword : oldPassword,
      storePublishDate: newPublishDate.isNotEmpty
          ? newUser.storePublishDate
          : oldPublishDate,
      activationDate: newActivationDate.isNotEmpty
          ? newUser.activationDate
          : oldActivationDate,
    );
  }

  // ============================================================
  // MERGE USER LISTS
  // ============================================================

  static List<UserModel> _mergeUserLists({
    required List<UserModel> existing,
    required List<UserModel> incoming,
  }) {
    final List<UserModel> result = [];

    // ----------------------------------------------------------
    // LOCAL
    // ----------------------------------------------------------

    for (final UserModel user in existing) {
      if (!_isPersistableUser(user)) {
        continue;
      }

      final int index = result.indexWhere((item) => _sameUser(item, user));

      if (index == -1) {
        result.add(user);
      }
    }

    // ----------------------------------------------------------
    // INCOMING
    // ----------------------------------------------------------

    for (final UserModel incomingUser in incoming) {
      if (!_isPersistableUser(incomingUser)) {
        continue;
      }

      final int index = result.indexWhere(
        (existingUser) => _sameUser(existingUser, incomingUser),
      );

      if (index == -1) {
        result.add(incomingUser);
      } else {
        result[index] = _preserveUserState(
          oldUser: result[index],
          newUser: incomingUser,
        );
      }
    }

    return result;
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
  // DECODE USERS
  // ============================================================

  static List<UserModel> _decodeUsers(String? encodedData) {
    final List<UserModel> users = [];

    if (encodedData == null || encodedData.trim().isEmpty) {
      return users;
    }

    try {
      final dynamic decoded = json.decode(encodedData);

      if (decoded is! List) {
        return users;
      }

      for (final dynamic item in decoded) {
        if (item is! Map) {
          continue;
        }

        try {
          final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item);

          final Map<String, dynamic> normalized = _normalizeUserMap(rawMap);

          final UserModel user = UserModel.fromJson(normalized);

          if (!_isPersistableUser(user)) {
            continue;
          }

          users.add(user);
        } catch (e) {
          debugPrint(
            '⚠️ [Local User Parse] '
            'تخطي مستخدم: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '❌ [Local JSON] '
        'بيانات المستخدمين تالفة: $e',
      );
    }

    return users;
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  static Future<void> loadUsers() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      await _migrateLocalUsersIfNeeded(prefs);

      String? encodedData = prefs.getString(savedUsersKey);

      // --------------------------------------------------------
      // RECOVERY
      // --------------------------------------------------------

      if (encodedData == null || encodedData.trim().isEmpty) {
        final String? backupData = prefs.getString(savedUsersBackupKey);

        if (backupData != null && backupData.trim().isNotEmpty) {
          encodedData = backupData;

          await prefs.setString(savedUsersKey, backupData);

          debugPrint(
            '♻️ [Local Recovery] '
            'تم استرجاع العملاء من النسخة الاحتياطية.',
          );
        }
      }

      final List<UserModel> localUsers = _decodeUsers(encodedData);

      registeredUsers = _mergeUserLists(
        existing: const [],
        incoming: localUsers,
      );

      _ensureAdmin();

      await _syncRegistrationSequenceFromUsers(prefs);

      _isLoaded = true;

      debugPrint(
        '✅ [BOOT] Local users loaded: '
        '${registeredUsers.length}',
      );

      debugPrint(
        '🔢 [Registration Sequence] '
        'آخر رقم: '
        '${await getLastRegistrationSequence()}',
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
  // LOCAL MIGRATION
  // ============================================================

  static Future<void> _migrateLocalUsersIfNeeded(
    SharedPreferences prefs,
  ) async {
    try {
      final int savedVersion = prefs.getInt(localUsersVersionKey) ?? 0;

      if (savedVersion >= currentLocalUsersVersion) {
        final String? existingData = prefs.getString(savedUsersKey);

        final String? backupData = prefs.getString(savedUsersBackupKey);

        if ((backupData == null || backupData.trim().isEmpty) &&
            existingData != null &&
            existingData.trim().isNotEmpty) {
          await prefs.setString(savedUsersBackupKey, existingData);
        }

        return;
      }

      debugPrint(
        '🔄 [Local Migration] '
        '$savedVersion -> '
        '$currentLocalUsersVersion',
      );

      final String? existingData = prefs.getString(savedUsersKey);

      if (existingData != null && existingData.trim().isNotEmpty) {
        await prefs.setString(savedUsersBackupKey, existingData);

        debugPrint(
          '🛡️ [Local Migration] '
          'تم إنشاء Backup للعملاء.',
        );
      }

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      debugPrint(
        '✅ [Local Migration] '
        'تم تحديث الإصدار بدون حذف العملاء.',
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
      return registeredUsers.firstWhere((u) => _sameUser(u, user));
    } catch (_) {
      return null;
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
  // REGISTRATION SEQUENCE
  // ============================================================

  static int? _extractRegistrationNumber(String? moxId) {
    final String value = _clean(moxId).toUpperCase();

    if (value.isEmpty) {
      return null;
    }

    final RegExp regex = RegExp(r'(\d+)$');

    final RegExpMatch? match = regex.firstMatch(value);

    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  static int _getHighestExistingRegistrationNumber() {
    int highest = _extractRegistrationNumber(adminUser.moxId) ?? 5000;

    for (final UserModel user in registeredUsers) {
      final int? number = _extractRegistrationNumber(user.moxId);

      if (number != null && number > highest) {
        highest = number;
      }
    }

    return highest;
  }

  static Future<void> _syncRegistrationSequenceFromUsers(
    SharedPreferences prefs,
  ) async {
    try {
      final int existingSequence =
          prefs.getInt(registrationSequenceKey) ?? 5000;

      final int highestExisting = _getHighestExistingRegistrationNumber();

      final int finalSequence = highestExisting > existingSequence
          ? highestExisting
          : existingSequence;

      if (finalSequence != existingSequence) {
        await prefs.setInt(registrationSequenceKey, finalSequence);

        debugPrint(
          '🔢 [Registration Sequence] '
          'تم رفع العداد إلى '
          '$finalSequence '
          'بناءً على العملاء الموجودين.',
        );
      }
    } catch (e) {
      debugPrint('❌ [Registration Sequence Sync] $e');
    }
  }

  static Future<int> getLastRegistrationSequence() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int saved = prefs.getInt(registrationSequenceKey) ?? 5000;

    final int existing = _getHighestExistingRegistrationNumber();

    return existing > saved ? existing : saved;
  }

  static Future<int> reserveNextRegistrationNumber() async {
    while (_registrationSequenceRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    _registrationSequenceRunning = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.reload();

      final int storedSequence = prefs.getInt(registrationSequenceKey) ?? 5000;

      final int highestExisting = _getHighestExistingRegistrationNumber();

      final int base = storedSequence > highestExisting
          ? storedSequence
          : highestExisting;

      final int nextNumber = base + 1;

      await prefs.setInt(registrationSequenceKey, nextNumber);

      debugPrint(
        '🔢 [NEW REGISTRATION] '
        'تم حجز الرقم: '
        '$nextNumber',
      );

      return nextNumber;
    } finally {
      _registrationSequenceRunning = false;
    }
  }

  static Future<String> reserveNextMoxId() async {
    final int number = await reserveNextRegistrationNumber();

    return 'ID-${number.toString().padLeft(6, '0')}';
  }

  static int getRegistrationCount() {
    return registeredUsers
        .where(
          (UserModel user) => !_isAdminUser(user) && _isPersistableUser(user),
        )
        .length;
  }

  static String getRegistrationCountText() {
    return getRegistrationCount().toString();
  }

  // ============================================================
  // STORE SUBSCRIPTION
  // ============================================================

  static DateTime? _parseDate(String? value) {
    final String date = _clean(value);

    if (date.isEmpty ||
        date.toLowerCase() == 'null' ||
        date.toLowerCase() == 'undefined') {
      return null;
    }

    return DateTime.tryParse(date);
  }

  static DateTime? getStoreStartDate(UserModel user) {
    final DateTime? publishDate = _parseDate(user.storePublishDate);

    if (publishDate != null) {
      return publishDate;
    }

    return _parseDate(user.activationDate);
  }

  static DateTime? getStoreExpiryDate(UserModel user) {
    final DateTime? startDate = getStoreStartDate(user);

    if (startDate == null) {
      return null;
    }

    return startDate.add(const Duration(days: storeSubscriptionDays));
  }

  static int getRemainingSubscriptionDays(UserModel user) {
    final DateTime? expiryDate = getStoreExpiryDate(user);

    if (expiryDate == null) {
      return 0;
    }

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime expiryDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    final int remaining = expiryDay.difference(today).inDays;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  static bool isSubscriptionActive(UserModel user) {
    return getRemainingSubscriptionDays(user) > 0;
  }

  static bool isSubscriptionExpired(UserModel user) {
    return !isSubscriptionActive(user);
  }

  static String getSubscriptionCounterText(UserModel user) {
    final int days = getRemainingSubscriptionDays(user);

    if (days <= 0) {
      return 'انتهى الاشتراك';
    }

    if (days == 1) {
      return 'متبقي يوم واحد';
    }

    if (days == 2) {
      return 'متبقي يومان';
    }

    return 'متبقي $days يوم';
  }

  static String? getStoreExpiryDateString(UserModel user) {
    final DateTime? expiry = getStoreExpiryDate(user);

    if (expiry == null) {
      return null;
    }

    return expiry.toIso8601String();
  }

  // ============================================================
  // CLOUD PARAMETERS
  // ============================================================

  static Map<String, String> _userCloudParameters(UserModel user) {
    final UserModel? existingLocalUser = _findLocalUser(user);

    String passwordToSend = _clean(user.password);

    if (passwordToSend.isEmpty && existingLocalUser != null) {
      final String oldPassword = _clean(existingLocalUser.password);

      if (oldPassword.isNotEmpty) {
        passwordToSend = oldPassword;
      }
    }

    final Map<String, String> params = <String, String>{
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

      'preservePassword': passwordToSend.isEmpty ? 'true' : 'false',
    };

    if (passwordToSend.isNotEmpty) {
      params['password'] = passwordToSend;
    }

    return params;
  }

  // ============================================================
  // SAVE TO GOOGLE CLOUD
  // ============================================================

  static Future<bool> _saveToCloud(UserModel user) async {
    try {
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      debugPrint(
        '☁️ [Cloud Save] '
        'إرسال: ${user.moxId}',
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
          '❌ [Cloud Save] '
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
              'رفض السيرفر: '
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

      await prefs.reload();

      final String? existingEncoded = prefs.getString(savedUsersKey);

      final List<UserModel> existingUsers = _decodeUsers(existingEncoded);

      final List<UserModel> mergedUsers = _mergeUserLists(
        existing: existingUsers,
        incoming: registeredUsers,
      );

      registeredUsers = mergedUsers;

      _ensureAdmin();

      final List<Map<String, dynamic>> jsonList = registeredUsers
          .where((u) => _isPersistableUser(u))
          .map((u) => u.toJson())
          .toList();

      final String encoded = json.encode(jsonList);

      if (existingEncoded != null && existingEncoded.trim().isNotEmpty) {
        await prefs.setString(savedUsersBackupKey, existingEncoded);
      }

      await prefs.setString(savedUsersKey, encoded);

      await _syncRegistrationSequenceFromUsers(prefs);

      await prefs.setInt(localUsersVersionKey, currentLocalUsersVersion);

      _isLoaded = true;

      debugPrint(
        '💾 [Local Save] '
        'تم حفظ ${jsonList.length} '
        'مستخدم.',
      );

      debugPrint(
        '👥 [Registration Counter] '
        'العملاء الحاليون: '
        '${getRegistrationCount()}',
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

    if (!_isPersistableUser(newUser)) {
      debugPrint(
        '❌ [Add User] '
        'هوية المستخدم غير صالحة.',
      );

      return;
    }

    final UserModel? oldUser = _findLocalUser(newUser);

    final UserModel protectedUser = _preserveUserState(
      oldUser: oldUser,
      newUser: newUser,
    );

    final bool cloudSaved = await _saveToCloud(protectedUser);

    if (!cloudSaved) {
      debugPrint(
        '⚠️ [Add User] '
        'فشل الحفظ السحابي، '
        'سيتم الاحتفاظ بالمحلي.',
      );
    }

    final int index = registeredUsers.indexWhere(
      (u) => _sameUser(u, protectedUser),
    );

    if (index == -1) {
      registeredUsers.add(protectedUser);
    } else {
      registeredUsers[index] = protectedUser;
    }

    _ensureAdmin();

    await saveUsersList();

    debugPrint(
      '👥 [Registration Counter] '
      'بعد التسجيل: '
      '${getRegistrationCount()}',
    );
  }

  // ============================================================
  // UPDATE USER PARTIAL
  // ============================================================

  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (!_isPersistableUser(user)) {
      throw Exception('لا يمكن تحديث المستخدم بدون هوية صالحة.');
    }

    final UserModel? oldUser = _findLocalUser(user);

    final UserModel protectedUser = _preserveUserState(
      oldUser: oldUser,
      newUser: user,
    );

    final bool cloudSaved = await _saveToCloud(protectedUser);

    if (!cloudSaved) {
      throw Exception('تعذر حفظ بيانات المتجر في Google Sheet.');
    }

    final int index = registeredUsers.indexWhere(
      (u) => _sameUser(u, protectedUser),
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

        if (_sameUser(activeUser, protectedUser)) {
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

      final UserModel protectedUser = _preserveUserState(
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
        (u) => _sameUser(u, protectedUser),
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
        'تم حفظ المستخدم.',
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

        if (!_isPersistableUser(user)) {
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

    registeredUsers = _mergeUserLists(
      existing: registeredUsers,
      incoming: users,
    );

    _ensureAdmin();

    _isLoaded = true;

    await saveUsersList();

    debugPrint(
      '👥 [Registration Counter] '
      'بعد Save Clients Data: '
      '${getRegistrationCount()}',
    );
  }

  // ============================================================
  // FETCH VERCEL USERS
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

          if (!_isPersistableUser(cloudUser)) {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint('⚠️ [Vercel User Parse] $e');
        }
      }

      debugPrint(
        '✅ [Vercel GetAll] '
        '${cloudUsers.length} عميل.',
      );

      return cloudUsers;
    } catch (e) {
      debugPrint('❌ [Vercel GetAll Exception] $e');

      return null;
    }
  }

  // ============================================================
  // FETCH GOOGLE USERS
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

          if (!_isPersistableUser(cloudUser)) {
            continue;
          }

          if (_isAdminUser(cloudUser)) {
            continue;
          }

          cloudUsers.add(cloudUser);
        } catch (e) {
          debugPrint('⚠️ [Google User Parse] $e');
        }
      }

      debugPrint(
        '✅ [Google GetAll] '
        '${cloudUsers.length} عميل.',
      );

      return cloudUsers;
    } catch (e) {
      debugPrint('❌ [Google GetAll Exception] $e');

      return null;
    }
  }

  // ============================================================
  // FETCH CLOUD USERS
  // ============================================================

  static Future<List<UserModel>?> _fetchAllUsersFromCloud() async {
    final List<UserModel>? vercelUsers = await _fetchAllUsersFromVercel();

    if (vercelUsers != null) {
      return vercelUsers;
    }

    debugPrint(
      '⚠️ [Cloud GetAll] '
      'Vercel فشل، نجرب Google.',
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

      final List<UserModel> localBeforeSync = List<UserModel>.from(
        registeredUsers,
      );

      final List<UserModel>? cloudUsers = await _fetchAllUsersFromCloud();

      if (cloudUsers == null) {
        debugPrint(
          '⚠️ [Cloud Sync] '
          'فشل الجلب، '
          'نحتفظ بالمحلي.',
        );

        return false;
      }

      registeredUsers = _mergeUserLists(
        existing: localBeforeSync,
        incoming: cloudUsers,
      );

      _ensureAdmin();

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await _syncRegistrationSequenceFromUsers(prefs);

      if (saveLocal) {
        await saveUsersList();
      }

      debugPrint(
        '☁️ [Cloud Sync] '
        'تم دمج العملاء: '
        '${getRegistrationCount()} '
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

      return await syncClientsFromCloud();
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

          final UserModel cloudUser = UserModel.fromJson(normalized);

          activatedUser = _preserveUserState(oldUser: user, newUser: cloudUser);

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

      final bool cloudSaved = await _saveToCloud(activatedUser);

      if (!cloudSaved) {
        debugPrint(
          '⚠️ [Store Activation] '
          'تعذر تحديث الشيت بعد التنشيط، '
          'لكن لن نفقد البيانات المحلية.',
        );
      }

      final int index = registeredUsers.indexWhere(
        (u) => _sameUser(u, activatedUser),
      );

      if (index == -1) {
        registeredUsers.add(activatedUser);
      } else {
        registeredUsers[index] = _preserveUserState(
          oldUser: registeredUsers[index],
          newUser: activatedUser,
        );
      }

      _ensureAdmin();

      await saveUsersList();

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(activatedUser.toJson()));

      debugPrint(
        '✅ [Store Activation] '
        'تم التنشيط.',
      );

      debugPrint(
        '🏪 [Subscription] '
        'المتبقي: '
        '${getRemainingSubscriptionDays(activatedUser)} يوم.',
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
  //
  // IMPORTANT:
  //
  // isMoxId == false
  // => FREE ACCOUNT LOGIN
  // => PHONE + PASSWORD
  //
  // isMoxId == true
  // => PROFESSIONAL ACCOUNT LOGIN
  // => guardianMoxId + PASSWORD
  //
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

    // ==========================================================
    // ADMIN
    // ==========================================================

    final bool isAdminLogin = _isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      guardianMoxId: isMoxId ? cleanInput : null,
    );

    if (isAdminLogin) {
      debugPrint(
        '👑 [Admin Login] '
        'تم التعرف على المدير.',
      );

      await syncAdminData();

      return adminUser;
    }

    // ==========================================================
    // LOCAL LOGIN
    // ==========================================================

    try {
      final UserModel foundUser = registeredUsers.firstWhere(
        (u) =>
            _isValidLoginIdentity(
              user: u,
              isMoxId: isMoxId,
              input: cleanInput,
            ) &&
            _clean(u.password) == cleanPassword,
      );

      debugPrint(
        '✅ [Local Login] '
        '${_isProfessionalAccount(foundUser) ? 'Professional' : 'Free'}',
      );

      return foundUser;
    } catch (_) {
      // لا يوجد محلياً.
    }

    // ==========================================================
    // CLOUD LOGIN
    // ==========================================================

    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',

          'input': cleanInput,

          'password': cleanPassword,

          'isMoxId': isMoxId.toString(),
        },
      );

      debugPrint(
        '🔐 [Cloud Login] '
        '${isMoxId ? 'guardianMoxId' : 'phone'}',
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

      if (map['status'] != 'success') {
        debugPrint(
          '❌ [Cloud Login] '
          'السيرفر رفض تسجيل الدخول.',
        );

        return null;
      }

      final dynamic rawUser = map['user'];

      if (rawUser is! Map) {
        return null;
      }

      final UserModel cloudUser = UserModel.fromJson(
        _normalizeUserMap(Map<String, dynamic>.from(rawUser)),
      );

      // ========================================================
      // ADMIN
      // ========================================================

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

      // ========================================================
      // VERIFY ACCOUNT TYPE
      // ========================================================

      final bool validIdentity = _isValidLoginIdentity(
        user: cloudUser,
        isMoxId: isMoxId,
        input: cleanInput,
      );

      if (!validIdentity) {
        debugPrint(
          '❌ [Cloud Login] '
          'طريقة الدخول لا تطابق نوع الحساب.',
        );

        debugPrint(
          'ℹ️ accountType='
          '${cloudUser.accountType}',
        );

        debugPrint(
          'ℹ️ isMoxId='
          '$isMoxId',
        );

        return null;
      }

      // ========================================================
      // NORMAL USER
      // ========================================================

      final UserModel? oldUser = _findLocalUser(cloudUser);

      final UserModel protectedUser = _preserveUserState(
        oldUser: oldUser,
        newUser: cloudUser,
      );

      final int index = registeredUsers.indexWhere(
        (u) => _sameUser(u, protectedUser),
      );

      if (index == -1) {
        registeredUsers.add(protectedUser);
      } else {
        registeredUsers[index] = protectedUser;
      }

      _ensureAdmin();

      await saveUsersList();

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(protectedUser.toJson()));

      debugPrint(
        '✅ [Cloud Login] '
        'نجح الدخول للحساب '
        '${_isProfessionalAccount(protectedUser) ? 'الاحترافي' : 'المجاني'}.',
      );

      return protectedUser;
    } catch (e) {
      debugPrint('❌ [Cloud Login] $e');

      return null;
    }
  }

  // ============================================================
  // CUSTOMER AUTHENTICATION
  // ============================================================
  //
  // LEGACY / COMPATIBILITY
  //
  // هذا المسار يحتاج PHONE + guardianMoxId.
  //
  // لا تستخدمه شاشة تسجيل الدخول الرئيسية الجديدة.
  //
  // ============================================================

  static Future<UserModel?> authenticateCustomerAsync({
    required String phone,
    required String guardianMoxId,
    required String password,
  }) async {
    await ensureLoaded();

    final String cleanPhone = phone.trim();

    final String cleanGuardian = guardianMoxId.trim().toUpperCase();

    final String cleanPassword = password.trim();

    if (cleanPhone.isEmpty || cleanGuardian.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // LOCAL CUSTOMER
    // ----------------------------------------------------------

    try {
      final UserModel localUser = registeredUsers.firstWhere((u) {
        final String userPhone = u.phone.trim();

        final String userGuardian = _clean(u.guardianMoxId).toUpperCase();

        final String userGuardianCustomer = _clean(
          u.guardianMoxIdCustomer,
        ).toUpperCase();

        final bool guardianMatches =
            userGuardian == cleanGuardian ||
            userGuardianCustomer == cleanGuardian;

        return userPhone == cleanPhone &&
            guardianMatches &&
            _clean(u.password) == cleanPassword;
      });

      debugPrint('✅ [Customer Local Login]');

      return localUser;
    } catch (_) {}

    // ----------------------------------------------------------
    // CLOUD CUSTOMER
    // ----------------------------------------------------------

    try {
      final Uri uri = Uri.parse(_scriptUrl).replace(
        queryParameters: {
          'action': 'login',

          'phone': cleanPhone,

          'guardianMoxId': cleanGuardian,

          'input': cleanPhone,

          'password': cleanPassword,

          'isMoxId': 'false',
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

      final String returnedPhone = cloudUser.phone.trim();

      final String returnedGuardian = _clean(
        cloudUser.guardianMoxId,
      ).toUpperCase();

      final String returnedGuardianCustomer = _clean(
        cloudUser.guardianMoxIdCustomer,
      ).toUpperCase();

      final bool phoneMatches = returnedPhone == cleanPhone;

      final bool guardianMatches =
          returnedGuardian == cleanGuardian ||
          returnedGuardianCustomer == cleanGuardian;

      if (!phoneMatches || !guardianMatches) {
        return null;
      }

      final UserModel? oldUser = _findLocalUser(cloudUser);

      final UserModel protectedUser = _preserveUserState(
        oldUser: oldUser,
        newUser: cloudUser.copyWith(
          password: cloudUser.password.trim().isNotEmpty
              ? cloudUser.password
              : cleanPassword,
        ),
      );

      final int index = registeredUsers.indexWhere(
        (u) => _sameUser(u, protectedUser),
      );

      if (index == -1) {
        registeredUsers.add(protectedUser);
      } else {
        registeredUsers[index] = protectedUser;
      }

      _ensureAdmin();

      await saveUsersList();

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(userKey, jsonEncode(protectedUser.toJson()));

      debugPrint(
        '✅ [Customer Cloud Login] '
        'تم تسجيل الدخول.',
      );

      return protectedUser;
    } catch (e) {
      debugPrint('❌ [Customer Cloud Login] $e');

      return null;
    }
  }

  // ============================================================
  // AUTHENTICATE SYNC
  // ============================================================
  //
  // نفس قاعدة تسجيل الدخول الرئيسية:
  //
  // FREE:
  // phone + password
  //
  // PROFESSIONAL:
  // guardianMoxId + password
  //
  // ============================================================

  static UserModel? authenticate(String input, String password, bool isMoxId) {
    final String cleanInput = input.trim();

    final String cleanPassword = password.trim();

    if (cleanInput.isEmpty || cleanPassword.isEmpty) {
      return null;
    }

    // ----------------------------------------------------------
    // ADMIN
    // ----------------------------------------------------------

    if (_isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      guardianMoxId: isMoxId ? cleanInput : null,
    )) {
      return adminUser;
    }

    // ----------------------------------------------------------
    // NORMAL USERS
    // ----------------------------------------------------------

    try {
      return registeredUsers.firstWhere(
        (u) =>
            _isValidLoginIdentity(
              user: u,
              isMoxId: isMoxId,
              input: cleanInput,
            ) &&
            _clean(u.password) == cleanPassword,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET USER BY MOX ID / PHONE / GUARDIAN
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

      if (response.statusCode == 200) {
        if (!_isHtmlResponse(response.body)) {
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
              final UserModel cloudUser = UserModel.fromJson(
                _normalizeUserMap(rawUser),
              );

              if (_isPersistableUser(cloudUser)) {
                if (!_isAdminUser(cloudUser)) {
                  final UserModel? oldUser = _findLocalUser(cloudUser);

                  final UserModel protectedUser = _preserveUserState(
                    oldUser: oldUser,
                    newUser: cloudUser,
                  );

                  final int index = registeredUsers.indexWhere(
                    (u) => _sameUser(u, protectedUser),
                  );

                  if (index == -1) {
                    registeredUsers.add(protectedUser);
                  } else {
                    registeredUsers[index] = protectedUser;
                  }

                  _ensureAdmin();

                  await saveUsersList();

                  return protectedUser;
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

    // ----------------------------------------------------------
    // LOCAL FALLBACK
    // ----------------------------------------------------------

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
