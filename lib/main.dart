// ignore: unused_import
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
// ignore: unused_import
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
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // WEB URL STRATEGY
  // ==========================================================

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ==========================================================
  // اقرأ الرابط فورًا
  //
  // مهم:
  // لا ننتظر Google Sheets ولا SharedPreferences
  // قبل معرفة هل نحن داخل /store/
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
      debugPrint('❌ [BOOT URL] $e');
    }
  }

  // ==========================================================
  // الشاشة الافتراضية
  // ==========================================================

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // PUBLIC STORE
  //
  // نعالج المتجر العام أولاً.
  // ==========================================================

  if (publicGuardianMoxId != null && publicGuardianMoxId.isNotEmpty) {
    try {
      final String guardianMoxId = publicGuardianMoxId;

      debugPrint('🏪 [PUBLIC STORE] بدء تحميل المتجر: $guardianMoxId');

      // ------------------------------------------------------
      // 1. تحميل Local
      // ------------------------------------------------------

      try {
        await StorageService.loadUsers();

        debugPrint(
          '✅ [PUBLIC STORE] Local users loaded: '
          '${StorageService.registeredUsers.length}',
        );
      } catch (e) {
        debugPrint('⚠️ [PUBLIC STORE] Local load error: $e');
      }

      // ------------------------------------------------------
      // 2. البحث المحلي
      // ------------------------------------------------------

      UserModel? foundUser = _findPublicUserLocally(guardianMoxId);

      // ------------------------------------------------------
      // 3. البحث السحابي
      // ------------------------------------------------------

      foundUser ??= await _findPublicUserFromCloud(guardianMoxId);

      // ------------------------------------------------------
      // 4. النتيجة
      // ------------------------------------------------------

      if (foundUser != null) {
        debugPrint('✅ [PUBLIC STORE] المتجر موجود');

        debugPrint('👤 [PUBLIC STORE] الاسم: ${foundUser.name}');

        debugPrint(
          '🆔 [PUBLIC STORE] guardianMoxId: '
          '${foundUser.guardianMoxId}',
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
// الرابط الوحيد:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// pathSegments:
//
// ["store", "MOX249-00010001"]
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
      '🔍 [LOCAL SEARCH] '
      'guardianMoxId: '
      '$cleanGuardianMoxId',
    );

    for (final UserModel user in StorageService.registeredUsers) {
      final String userGuardianMoxId = (user.guardianMoxId ?? '')
          .trim()
          .toUpperCase();

      // ======================================================
      // المطابقة الوحيدة
      // ======================================================

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
// ☁️ البحث في Google Sheets
//
// المطابقة الوحيدة:
//
// guardianMoxId
//
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '☁️ [CLOUD SEARCH] البحث المباشر عن العميل: $cleanGuardianMoxId',
    );

    // ========================================================
    // الاعتماد على StorageService المعتمدة لجلب وتدقيق العميل
    // ========================================================

    final UserModel? user = await StorageService.getUserByMoxId(
      cleanGuardianMoxId,
    );

    if (user == null) {
      debugPrint('❌ [CLOUD SEARCH] فشل الجلب أو العميل غير موجود');
      return null;
    }

    final String rowGuardianMoxId = (user.guardianMoxId ?? '')
        .trim()
        .toUpperCase();

    if (!_isValidGuardianMoxId(rowGuardianMoxId)) {
      debugPrint('⚠️ [CLOUD SEARCH] المعرف المسترجع غير صالح');
      return null;
    }

    debugPrint('✅ [CLOUD SEARCH] MATCH العميل: ${user.name}');

    // ========================================================
    // تحديث النسخة المحلية للتخزين المؤقت
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

    debugPrint('💾 [CLOUD SEARCH] تم تحديث النسخة المحلية للعميل بنجاح');

    return user;
  } catch (e) {
    debugPrint('❌ [CLOUD SEARCH ERROR] $e');
  }

  return null;
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
