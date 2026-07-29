import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';

// القائمة المركزية للمنظومة
List<UserModel> registeredUsers = [];

// مرجع قاعدة البيانات السيادية
Database? _database;

// تعريف المدير ببياناته السيادية الموحدة
final UserModel adminUser = UserModel(
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

// دالة تهيئة وفتح قاعدة البيانات المحلية عبر sqflite بالمسطرة
Future<Database> get database async {
  if (_database != null) return _database!;
  _database = await _initDB('mox_sovereign_db.db');
  return _database!;
}

Future<Database> _initDB(String filePath) async {
  final dbPath = await getDatabasesPath();
  const dbFolder = 'mox_vault';
  // التأكد من المسار
  final path = join(dbPath, dbFolder, filePath);

  return await openDatabase(path, version: 1, onCreate: _createDB);
}

Future<void> _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE users (
      phone TEXT PRIMARY KEY,
      password TEXT,
      name TEXT,
      address TEXT,
      balance REAL,
      gender TEXT,
      accountType TEXT,
      moxId TEXT,
      role TEXT,
      points INTEGER,
      guardianMoxId TEXT
    )
  ''');

  // إدراج المدير الافتراضي عند الإنشاء الأول
  await db.insert(
    'users',
    adminUser.toJson(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// دالة التحميل السيادية من قاعدة البيانات المحلية الحقيقية
Future<void> loadUsers() async {
  try {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');

    if (maps.isNotEmpty) {
      registeredUsers = maps.map((item) => UserModel.fromJson(item)).toList();
      debugPrint(
        "🏛️ [SQLite Data] تم تحميل ${registeredUsers.length} مواطن من قاعدة البيانات بنجاح.",
      );

      // التأكد من وجود المدير في رأس السجل
      if (!registeredUsers.any((u) => u.moxId == adminUser.moxId)) {
        registeredUsers.insert(0, adminUser);
        await saveUsers();
        debugPrint("🏛️ [SQLite Data] المدير لم يكن موجوداً، تم تثبيته.");
      }
    } else {
      registeredUsers = [adminUser];
      await saveUsers();
      debugPrint(
        "🏛️ [SQLite Data] السجل كان فارغاً، تم تثبيت المدير كأول إدخال.",
      );
    }
  } catch (e) {
    debugPrint("❌ [SQLite Data] خطأ فادح أثناء تحميل السجل: $e");
    registeredUsers = [adminUser];
  }
}

// دالة الحفظ الدائم في قاعدة البيانات المحلية
Future<void> saveUsers() async {
  try {
    final db = await database;
    // حفظ أو تحديث كافة المستخدمين في قاعدة البيانات
    for (var user in registeredUsers) {
      await db.insert(
        'users',
        user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    debugPrint(
      "✅ [SQLite Data] تم حفظ السجل الكامل للعملاء في قاعدة البيانات المحلية بنجاح.",
    );
  } catch (e) {
    debugPrint("❌ [SQLite Data] خطأ أثناء الحفظ في قاعدة البيانات: $e");
  }
}

// دالة إضافة عميل جديد وتثبيته فوراً بالخزينة الحديدية للأبد
Future<void> addUser(UserModel newUser) async {
  await loadUsers(); // التأكد من تحميل أحدث نسخة قبل التعديل

  int index = registeredUsers.indexWhere(
    (u) =>
        u.phone == newUser.phone ||
        (newUser.moxId != "لم يحدد" && u.moxId == newUser.moxId),
  );

  if (index != -1) {
    registeredUsers[index] = newUser;
    debugPrint("🔄 [SQLite Data] العميل موجود مسبقاً، تم تحديث بياناته بنجاح.");
  } else {
    registeredUsers.add(newUser);
    debugPrint(
      "➕ [SQLite Data] تم إضافة العميل الجديد ${newUser.name} وحفظه في القاعدة للأبد.",
    );
  }

  await saveUsers();
}

// دالة التحقق من الدخول
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
