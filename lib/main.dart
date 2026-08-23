import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:http/http.dart' as http;

import 'models/user_model.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/storage_service.dart';
import 'widgets/store_preview_widget.dart';

// ============================================================
// MOX DIGITAL
// MAIN
//
// الرابط العام الوحيد المعتمد:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// الهوية المستخدمة في المتجر العام:
//
// guardianMoxId
//
// لا نستخدم في تحديد المتجر العام:
//
// moxId
// phone
// guardianMoxIdCustomer
//
// ============================================================
// ============================================================
// VERCEL STORE API
//
// Flutter لا يتصل بـ Google Apps Script مباشرة.
//
// المسار:
//
// Flutter
//   ↓
// Vercel /api/store
//   ↓
// Google Apps Script
//   ↓
// JSON
//
// ============================================================

const String publicStoreApi = 'https://mox-2026.vercel.app/api/store';

// تخزين مؤقت للرابط في حال لم يكن المستخدم مسجل دخول
String? pendingPublicGuardianMoxId;

// ============================================================
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // WEB URL STRATEGY
  // ==========================================================

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ==========================================================
  // استخراج رابط المتجر فورًا
  //
  // لا ننتظر:
  // Google Sheets
  // SharedPreferences
  // StorageService
  //
  // أول شيء نعرف هل نحن داخل /store/
  // ==========================================================

  String? publicGuardianMoxId;

  if (kIsWeb) {
    try {
      final Uri uri = Uri.base;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 [BOOT] URI      : ${uri.toString()}');
      debugPrint('🌐 [BOOT] PATH     : ${uri.path}');
      debugPrint('🌐 [BOOT] SEGMENTS : ${uri.pathSegments}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      publicGuardianMoxId = _getPublicGuardianMoxIdFromUrl();

      debugPrint('🏪 [BOOT] GUARDIAN : $publicGuardianMoxId');
    } catch (e) {
      debugPrint('❌ [BOOT URL ERROR] $e');
    }
  }

  // ==========================================================
  // الشاشة الافتراضية
  // ==========================================================

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // PUBLIC STORE
  //
  // إذا كان الرابط:
  //
  // /store/MOX249-00010001
  //
  // نعالج المتجر العام أولًا.
  // ==========================================================

  if (publicGuardianMoxId != null && publicGuardianMoxId.isNotEmpty) {
    try {
      final String guardianMoxId = publicGuardianMoxId;

      debugPrint(
        '🏪 [PUBLIC STORE] بدء تحميل المتجر: '
        '$guardianMoxId',
      );

      // ======================================================
      // 1. تحميل المستخدمين المحليين
      // ======================================================

      try {
        await StorageService.loadUsers();

        debugPrint(
          '✅ [PUBLIC STORE] Local users loaded: '
          '${StorageService.registeredUsers.length}',
        );
      } catch (e) {
        debugPrint('⚠️ [PUBLIC STORE] Local load error: $e');
      }

      // ======================================================
      // 2. البحث المحلي
      // ======================================================

      UserModel? foundUser = _findPublicUserLocally(guardianMoxId);

      // ======================================================
      // 3. إذا لم نجده محليًا
      //
      // نذهب إلى Vercel API
      // ======================================================

      foundUser ??= await _findPublicUserFromCloud(guardianMoxId);

      // ======================================================
      // 4. النتيجة
      // ======================================================

      if (foundUser != null) {
        debugPrint('✅ [PUBLIC STORE] المتجر موجود');

        debugPrint(
          '👤 [PUBLIC STORE] الاسم: '
          '${foundUser.name}',
        );

        debugPrint(
          '🆔 [PUBLIC STORE] guardianMoxId: '
          '${foundUser.guardianMoxId}',
        );

        debugPrint(
          '📅 [PUBLIC STORE] storePublishDate: '
          '${foundUser.storePublishDate}',
        );

        debugPrint(
          '🧾 [PUBLIC STORE] myAssets: '
          '${foundUser.myAssets.length}',
        );

        initialScreen = _buildPublicStoreScreen(foundUser);
      } else {
        debugPrint(
          '⚠️ [PUBLIC STORE] المتجر غير موجود: '
          '$guardianMoxId',
        );

        initialScreen = _buildStoreNotFoundScreen(guardianMoxId);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [PUBLIC STORE ERROR] $e');

      debugPrint('$stackTrace');

      initialScreen = const WelcomeScreen();
    }
  }
  // ==========================================================
  // NORMAL APPLICATION
  //
  // فقط إذا لم يكن الرابط /store/
  // ==========================================================
  else {
    try {
      debugPrint('ℹ️ [MAIN] لا يوجد رابط متجر عام');

      await StorageService.loadUsers();

      final UserModel? savedUser = await StorageService.getUser();

      if (savedUser != null) {
        debugPrint('🔐 [REMEMBER LOGIN] جلسة محفوظة موجودة');

        initialScreen = DashboardScreen(user: savedUser);
      } else {
        debugPrint('🔓 [REMEMBER LOGIN] لا توجد جلسة محفوظة');

        initialScreen = const WelcomeScreen();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [MAIN ERROR] $e');

      debugPrint('$stackTrace');

      initialScreen = const WelcomeScreen();
    }
  }

  // ==========================================================
  // RUN APP
  // ==========================================================

  debugPrint('🚀 [BOOT] تشغيل التطبيق...');

  debugPrint(
    '🚀 [BOOT] initialScreen: '
    '${initialScreen.runtimeType}',
  );

  runApp(MyApp(initialScreen: initialScreen));
}

// ============================================================
// 🏪 بناء شاشة المتجر العام
// ============================================================

Widget _buildPublicStoreScreen(UserModel user) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: StorePreviewWidget(user: user, isPublicView: true),
  );
}

// ============================================================
// ⚠️ شاشة المتجر غير موجود
// ============================================================

Widget _buildStoreNotFoundScreen(String guardianMoxId) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 18),

            const Text(
              'المتجر غير موجود',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'تأكد من رابط العميل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),

            const SizedBox(height: 12),

            Text(
              guardianMoxId,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF28A9CC),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// 🔗 استخراج guardianMoxId من الرابط
//
// الرابط:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// ============================================================

String? _getPublicGuardianMoxIdFromUrl() {
  try {
    final Uri uri = Uri.base;

    final List<String> segments = uri.pathSegments;

    debugPrint(
      '🔗 [URL PARSER] URI: '
      '${uri.toString()}',
    );

    debugPrint(
      '🔗 [URL PARSER] PATH: '
      '${uri.path}',
    );

    debugPrint(
      '🔗 [URL PARSER] SEGMENTS: '
      '$segments',
    );

    // ========================================================
    // يجب أن يكون:
    //
    // /store/IDENTIFIER
    // ========================================================

    if (segments.length != 2) {
      debugPrint(
        'ℹ️ [URL PARSER] '
        'المسار ليس رابط متجر كامل',
      );

      return null;
    }

    // ========================================================
    // الجزء الأول يجب أن يكون store
    // ========================================================

    if (segments[0].trim().toLowerCase() != 'store') {
      debugPrint(
        'ℹ️ [URL PARSER] '
        'المسار لا يبدأ بـ /store/',
      );

      return null;
    }

    // ========================================================
    // استخراج guardianMoxId
    // ========================================================

    final String guardianMoxId = Uri.decodeComponent(
      segments[1],
    ).trim().toUpperCase();

    // ========================================================
    // التحقق
    // ========================================================

    if (!_isValidGuardianMoxId(guardianMoxId)) {
      debugPrint(
        '⚠️ [URL PARSER] '
        'guardianMoxId غير صالح',
      );

      return null;
    }

    debugPrint(
      '🏪 [URL PARSER] guardianMoxId = '
      '$guardianMoxId',
    );

    return guardianMoxId;
  } catch (e) {
    debugPrint('❌ [URL PARSER] $e');

    return null;
  }
}

// ============================================================
// 🔎 التحقق من guardianMoxId
// ============================================================

bool _isValidGuardianMoxId(String value) {
  final String normalized = value.trim().toUpperCase();

  if (normalized.isEmpty) {
    return false;
  }

  if (normalized == 'NULL') {
    return false;
  }

  if (normalized == 'UNDEFINED') {
    return false;
  }

  if (normalized == 'N/A') {
    return false;
  }

  if (normalized == 'لم يحدد') {
    return false;
  }

  return true;
}

// ============================================================
// 🔎 البحث المحلي
//
// المطابقة الوحيدة:
//
// guardianMoxId
//
// ============================================================

UserModel? _findPublicUserLocally(String guardianMoxId) {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '🔍 [LOCAL SEARCH] guardianMoxId: '
      '$cleanGuardianMoxId',
    );

    for (final UserModel user in StorageService.registeredUsers) {
      final String userGuardianMoxId = (user.guardianMoxId ?? '')
          .trim()
          .toUpperCase();

      if (userGuardianMoxId == cleanGuardianMoxId) {
        debugPrint('✅ [LOCAL SEARCH] MATCH');

        debugPrint(
          '👤 [LOCAL SEARCH] العميل: '
          '${user.name}',
        );

        debugPrint(
          '🆔 [LOCAL SEARCH] guardianMoxId: '
          '$userGuardianMoxId',
        );

        return user;
      }
    }
  } catch (e) {
    debugPrint('❌ [LOCAL SEARCH] $e');
  }

  return null;
}

// ============================================================
// ☁️ البحث السحابي للمتجر العام
//
// مهم:
//
// لا نستخدم getUserByMoxId هنا.
//
// الرابط العام يعتمد على guardianMoxId فقط.
//
// Flutter → Vercel API → Google Apps Script
//
// ============================================================

// ============================================================
// ☁️ البحث السحابي للمتجر العام
//
// مهم:
//
// لا نستخدم getUserByMoxId هنا.
//
// الرابط العام يعتمد على guardianMoxId فقط.
//
// Flutter → Vercel API → Google Apps Script
//
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '☁️ [CLOUD SEARCH] البحث عن المتجر: '
      '$cleanGuardianMoxId',
    );

    // ========================================================
    // VERCEL API
    // ========================================================

    final Uri uri = Uri.parse(
      publicStoreApi,
    ).replace(queryParameters: {'guardianMoxId': cleanGuardianMoxId});

    debugPrint(
      '🌐 [STORE API] URL: '
      '$uri',
    );

    // ========================================================
    // HTTP GET
    // ========================================================

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));

    debugPrint(
      '🌐 [STORE API] HTTP: '
      '${response.statusCode}',
    );

    debugPrint(
      '🌐 [STORE API] BODY LENGTH: '
      '${response.body.length}',
    );

    // ========================================================
    // HTTP ERROR
    // ========================================================

    if (response.statusCode != 200) {
      debugPrint(
        '❌ [STORE API] HTTP ERROR: '
        '${response.statusCode}',
      );

      debugPrint(
        '❌ [STORE API] BODY: '
        '${response.body}',
      );

      return null;
    }

    if (response.body.trim().isEmpty) {
      debugPrint('❌ [STORE API] الرد فارغ');

      return null;
    }

    // ========================================================
    // JSON
    //
    // الحماية المهمة:
    //
    // لا نحاول jsonDecode قبل التأكد
    // أن الرد ليس HTML.
    // ========================================================

    final String body = response.body.trim();

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<HTML')) {
      debugPrint(
        '❌ [STORE API] '
        'الرد HTML وليس JSON',
      );

      return null;
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (e) {
      debugPrint(
        '❌ [STORE API] JSON decode error: '
        '$e',
      );

      debugPrint(
        '❌ [STORE API] RESPONSE: '
        '$body',
      );

      return null;
    }

    // ========================================================
    // الرد يجب أن يكون Map
    // ========================================================

    if (decoded is! Map) {
      debugPrint(
        '❌ [STORE API] '
        'الرد ليس Map',
      );

      return null;
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

    // ========================================================
    // إذا كان API يعيد success:false
    // ========================================================

    if (map['success'] == false) {
      debugPrint(
        '⚠️ [STORE API] '
        '${map['message'] ?? 'فشل تحميل المتجر'}',
      );

      return null;
    }

    // ========================================================
    // التحقق من guardianMoxId
    // ========================================================

    final String rowGuardianMoxId = (map['guardianMoxId'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (!_isValidGuardianMoxId(rowGuardianMoxId)) {
      debugPrint(
        '⚠️ [STORE API] '
        'guardianMoxId المسترجع غير صالح',
      );

      return null;
    }

    if (rowGuardianMoxId != cleanGuardianMoxId) {
      debugPrint(
        '❌ [STORE API] '
        'guardianMoxId لا يطابق الرابط',
      );

      debugPrint('الرابط: $cleanGuardianMoxId');

      debugPrint('البيانات: $rowGuardianMoxId');

      return null;
    }

    // ========================================================
    // بناء UserModel (التعديل الحاسم لاستخراج بيانات user الفرعية)
    // ========================================================

    // استخراج الخريطة بذكاء بغض النظر عن طريقة تغليفها في قوقل
    final Map<String, dynamic> userMap = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'])
        : (map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map);

    // 🔍 طباعة تفحصية سريعة لنرى مفاتيح الخريطة القادمة من قوقل
    debugPrint('🔍 [MAP KEYS]: ${userMap.keys.toList()}');
    debugPrint(
      '🔍 [RAW storePublishDate in Map]: ${userMap['storePublishDate'] ?? userMap['StorePublishDate'] ?? userMap['STORE_PUBLISH_DATE']}',
    );

    final UserModel user = UserModel.fromJson(userMap);

    debugPrint(
      '✅ [CLOUD SEARCH] MATCH العميل: '
      '${user.name}',
    );

    debugPrint(
      '🆔 [CLOUD SEARCH] guardianMoxId: '
      '${user.guardianMoxId}',
    );

    debugPrint(
      '📅 [CLOUD SEARCH] storePublishDate: '
      '${user.storePublishDate}',
    );

    debugPrint(
      '🧾 [CLOUD SEARCH] myAssets: '
      '${user.myAssets.length}',
    );

    // ========================================================
    // تحديث النسخة المحلية
    // ========================================================

    final int index = StorageService.registeredUsers.indexWhere((u) {
      final String localGuardian = (u.guardianMoxId ?? '').trim().toUpperCase();

      return localGuardian == rowGuardianMoxId;
    });

    if (index == -1) {
      StorageService.registeredUsers.add(user);
    } else {
      StorageService.registeredUsers[index] = user;
    }

    debugPrint(
      '💾 [CLOUD SEARCH] '
      'تم تحديث النسخة المحلية للعميل',
    );

    return user;
  } catch (e, stackTrace) {
    debugPrint('❌ [CLOUD SEARCH ERROR] $e');

    debugPrint('$stackTrace');

    return null;
  }
}
// ============================================================
// MY APP
// ============================================================

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'MOX Digital App',

      theme: ThemeData(
        primaryColor: const Color(0xFF28A9CC),

        scaffoldBackgroundColor: Colors.white,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28A9CC),

          primary: const Color(0xFF28A9CC),

          surface: Colors.white,
        ),

        useMaterial3: true,

        fontFamily: 'Cairo',
      ),

      home: initialScreen,
    );
  }
}
