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
      'https://script.google.com/macros/s/AKfycbycCPFDCesTBzuQWhlpeBiacAu9snNz-f65GvcbbDOQ8q-Y2sKR8T40VW6Lwr4AWyO/exec';

  // ============================================================
  // ADMIN
  // ============================================================
  //
  // 🔐 مهم جدًا:
  // لا توجد كلمة سر للإدارة داخل Flutter.
  //
  // كلمة سر الإدارة موجودة في Google Sheet فقط.
  //
  // ============================================================

  static final UserModel adminUser = UserModel(
    phone: '249115855164',

    // ❌ لا تضع كلمة سر الإدارة هنا.
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
      // 🔐 مهم:
      // لا نستورد كلمة سر الإدارة من Local Storage.
      //
      // نضمن أن النسخة المحلية للإدارة
      // لا تحمل كلمة سر.
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

          // 🔐 لا نستورد كلمة سر الإدارة.
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
          (u) => u.phone == cloudUser.phone || u.moxId == cloudUser.moxId,
        );

        if (index != -1) {
          registeredUsers[index] = cloudUser;
        } else {
          registeredUsers.add(cloudUser);
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

    // ==========================================================
    // 🔐 PASSWORD
    // ==========================================================
    //
    // المستخدم العادي:
    // نرسل كلمة السر.
    //
    // الإدارة:
    // لا نرسل كلمة السر إطلاقًا.
    //
    // Apps Script سيحافظ على كلمة السر
    // الموجودة أصلًا في Google Sheet.
    //
    // ==========================================================

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
      (u) =>
          u.phone == newUser.phone ||
          (newUser.moxId != 'ID-000001' && u.moxId == newUser.moxId),
    );

    if (index != -1) {
      registeredUsers[index] = newUser;
    } else {
      registeredUsers.add(newUser);
    }

    _ensureAdmin();

    await saveUsersList();

    // الإدارة يمكن تحديث بياناتها،
    // لكن كلمة سرها لا تغادر Google Sheet.
    await _saveToCloud(newUser);
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  static Future<void> updateUserPartial(UserModel user) async {
    await ensureLoaded();

    if (user.moxId.trim().isEmpty || user.moxId == 'null') {
      debugPrint('❌ تحديث مرفوض: MoxId فارغ.');
      return;
    }

    final index = registeredUsers.indexWhere(
      (u) => u.moxId == user.moxId || u.phone == user.phone,
    );

    if (index != -1) {
      registeredUsers[index] = user;
    } else {
      registeredUsers.add(user);
    }

    // 🔐 الإدارة محليًا لا تحمل كلمة سر.
    _ensureAdmin();

    await saveUsersList();

    // ========================================================
    // تحديث الجلسة الحالية
    // ========================================================

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

    await _saveToCloud(user);
  }

  // ============================================================
  // SAVE TO CLOUD
  // ============================================================

  static Future<void> _saveToCloud(UserModel user) async {
    try {
      final uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: _userCloudParameters(user));

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      debugPrint('☁️ [Cloud Save] ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ [Cloud Save] $e');
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

      // 🔐 الإدارة لا تحتفظ بكلمة سر محليًا.
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

    // ========================================================
    // 🔐 ADMIN = CLOUD ONLY
    // ========================================================
    //
    // الإدارة لا يتم التحقق منها محليًا.
    // كلمة السر لا توجد داخل Flutter.
    //
    // ========================================================

    final isAdminLogin = _isAdminIdentity(
      phone: isMoxId ? null : cleanInput,
      moxId: isMoxId ? cleanInput : null,
    );

    // ========================================================
    // 1. LOCAL LOGIN
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
    // 2. CLOUD LOGIN
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
      // 🔐 ADMIN
      // ======================================================

      if (_isAdminUser(cloudUser)) {
        // لا نخزن كلمة السر التي رجعت من السيرفر.
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

    // 🔐 الإدارة لا يتم تسجيل دخولها
    // بالطريقة المتزامنة المحلية.
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
    try {
      await ensureLoaded();

      final cleanMoxId = moxId.trim();

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
