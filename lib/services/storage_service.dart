import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';

class StorageService {
  static const String userKey = 'current_mox_user';
  static const String savedUsersKey = 'saved_users';

  static List<UserModel> registeredUsers = [];
  static bool _isLoaded = false;
  static Database? _database;

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

  // تهيئة قاعدة البيانات الصلبة (SQLite) كخزينة احتياطية لا تُمسح بالـ Clean
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mox_digital_vault.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            phone TEXT PRIMARY KEY,
            moxId TEXT,
            password TEXT,
            name TEXT,
            address TEXT,
            balance REAL,
            commission REAL,
            gender TEXT,
            accountType TEXT,
            role TEXT,
            points INTEGER,
            guardianMoxId TEXT,
            customWhatsApp TEXT,
            myAssets TEXT
          )
        ''');
      },
    );
  }

  // دالة التحميل المزدوجة (تتفقد SharedPreferences أولاً، وإذا فرغت تستعيد من SQLite)
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
      } else {
        // محاولة الاستعادة من الخزينة الصلبة SQLite إذا تفرغت الشيرد بريفرنسز
        try {
          final db = await database;
          final List<Map<String, dynamic>> maps = await db.query('users');
          if (maps.isNotEmpty) {
            registeredUsers = maps
                .map((item) => UserModel.fromMap(item))
                .toList();
            // مزامنة عكسية للشيرد بريفرنسز لتظل المنظومة سريعة
            await saveUsersList();
          }
        } catch (_) {}
      }

      // التأكد من وجود المدير السيادي دائماً
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
        await saveUsersList();
      }

      _isLoaded = true;
      debugPrint(
        "🏛️ [Storage Dual] تم تحميل ${registeredUsers.length} مواطن بنجاح.",
      );
    } catch (e) {
      debugPrint("❌ [Storage Dual] خطأ أثناء التحميل: $e");
      registeredUsers = [adminUser];
      _isLoaded = true;
    }
  }

  static Future<void> ensureLoaded() async {
    if (!_isLoaded || registeredUsers.isEmpty) {
      await loadUsers();
    }
  }

  // دالة الحفظ المزدوجة (تحدث SharedPreferences و SQLite معاً)
  static Future<void> saveUsersList() async {
    try {
      // 1. الحفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> jsonList = registeredUsers
          .map((u) => u.toJson())
          .toList();
      await prefs.setString(savedUsersKey, json.encode(jsonList));

      // 2. الحفظ في SQLite لضمان عدم الضياع عند عمل Clean أو تحديث Build
      final db = await database;
      for (var user in registeredUsers) {
        await db.insert(
          'users',
          user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      _isLoaded = true;
      debugPrint(
        "✅ [Storage Dual] تم حفظ السجل وتأمينه في الخزينة المزدوجة بنجاح.",
      );
    } catch (e) {
      debugPrint("❌ [Storage Dual] خطأ أثناء الحفظ المزدوج: $e");
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
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String userJson = jsonEncode(user.toJson());
      await prefs.setString(userKey, userJson);

      await addUser(user);
      debugPrint("🏛️ [Storage Dual] حفظ العميل النشط: ${user.name}");
    } catch (e) {
      debugPrint("❌ [Storage Dual] خطأ في حفظ العميل النشط: $e");
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
