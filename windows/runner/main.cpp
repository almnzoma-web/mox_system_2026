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
// النظام المعتمد للمتجر العام:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// IMPORTANT:
//
// guardianMoxId = هوية MOX اليدوية للمتجر العام
//
// moxId = رقم تلقائي داخلي للعميل
//
// لذلك:
// المتجر العام يبحث بـ guardianMoxId فقط.
//
// لا نستخدم:
// - moxId
// - phone
// - guardianMoxIdCustomer
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
  // تحميل المستخدمين
  // ==========================================================

  try {
    await StorageService.loadUsers();
  } catch (e) {
    debugPrint('❌ [MAIN] خطأ في تحميل المستخدمين: $e');
  }

  // ==========================================================
  // الشاشة الافتراضية
  // ==========================================================

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // WEB
  // ==========================================================

  if (kIsWeb) {
    try {
      // ========================================================
      // معرفة هل الرابط متجر عام
      // ========================================================

      final String? guardianMoxId = _getPublicGuardianMoxIdFromUrl();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 [MAIN] URL      : ${Uri.base}');
      debugPrint('🌐 [MAIN] PATH     : ${Uri.base.path}');
      debugPrint('🌐 [MAIN] GUARDIAN : $guardianMoxId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ========================================================
      // متجر عام
      // ========================================================

      if (guardianMoxId != null && guardianMoxId.isNotEmpty) {
        debugPrint(
          '🏪 [PUBLIC STORE] البحث عن guardianMoxId: $guardianMoxId',
        );

        // ------------------------------------------------------
        // 1. البحث في الذاكرة المحلية
        // ------------------------------------------------------

        UserModel? foundUser =
            _findPublicUserLocally(guardianMoxId);

        // ------------------------------------------------------
        // 2. إذا لم يوجد محلياً → Google Sheets
        // ------------------------------------------------------

        foundUser ??=
            await _findPublicUserFromCloud(guardianMoxId);

        // ------------------------------------------------------
        // 3. وجدنا المتجر
        // ------------------------------------------------------

        if (foundUser != null) {
          debugPrint(
            '✅ [PUBLIC STORE] تم العثور على المتجر',
          );

          initialScreen = Scaffold(
            backgroundColor: Colors.white,
            body: StorePreviewWidget(
              user: foundUser,
              isPublicView: true,
            ),
          );
        } else {
          // ----------------------------------------------------
          // المتجر غير موجود
          // ----------------------------------------------------

          debugPrint(
            '⚠️ [PUBLIC STORE] '
            'لم يتم العثور على guardianMoxId: $guardianMoxId',
          );

          // نترك WelcomeScreen كما هي
          // ولا نعرض لوحة المستخدم.
        }
      }

      // ========================================================
      // لا يوجد /store/
      //
      // نفحص الجلسة المحفوظة
      // ========================================================

      else {
        debugPrint(
          'ℹ️ [MAIN] لا يوجد رابط متجر عام',
        );

        final UserModel? savedUser =
            await StorageService.getUser();

        if (savedUser != null) {
          debugPrint(
            '🔐 [REMEMBER LOGIN] جلسة محفوظة موجودة',
          );

          initialScreen =
              DashboardScreen(user: savedUser);
        } else {
          debugPrint(
            '🔓 [REMEMBER LOGIN] لا توجد جلسة محفوظة',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [MAIN ERROR] $e');
      debugPrint('$stackTrace');
    }
  }

  // ==========================================================
  // تشغيل التطبيق
  // ==========================================================

  runApp(
    MyApp(
      initialScreen: initialScreen,
    ),
  );
}

// ============================================================
// 🔗 استخراج guardianMoxId من رابط المتجر
//
// الرابط الوحيد المعتمد:
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
      '🔗 [URL PARSER] URI: ${uri.toString()}',
    );

    debugPrint(
      '🔗 [URL PARSER] PATH: ${uri.path}',
    );

    debugPrint(
      '🔗 [URL PARSER] SEGMENTS: $segments',
    );

    // ========================================================
    // يجب أن يكون الرابط:
    //
    // /store/IDENTIFIER
    // ========================================================

    if (segments.length < 2) {
      debugPrint(
        'ℹ️ [URL PARSER] لا يوجد مسار متجر عام',
      );

      return null;
    }

    // ========================================================
    // أول جزء يجب أن يكون store
    // ========================================================

    if (segments[0].toLowerCase() != 'store') {
      debugPrint(
        'ℹ️ [URL PARSER] المسار ليس /store/',
      );

      return null;
    }

    // ========================================================
    // استخراج guardianMoxId
    // ========================================================

    final String guardianMoxId = Uri.decodeComponent(
      segments[1],
    ).trim().toUpperCase();

    if (!_isValidGuardianMoxId(guardianMoxId)) {
      debugPrint(
        '⚠️ [URL PARSER] guardianMoxId غير صالح',
      );

      return null;
    }

    debugPrint(
      '🏪 [URL PARSER] guardianMoxId = $guardianMoxId',
    );

    return guardianMoxId;
  } catch (e) {
    debugPrint(
      '❌ [URL PARSER] $e',
    );

    return null;
  }
}

// ============================================================
// 🔎 التحقق من guardianMoxId
// ============================================================

bool _isValidGuardianMoxId(String value) {
  final String normalized =
      value.trim().toUpperCase();

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
// 🔎 البحث المحلي عن المتجر
//
// مهم جداً:
//
// المطابقة هنا guardianMoxId فقط.
//
// لا نستخدم moxId.
// لا نستخدم phone.
// لا نستخدم guardianMoxIdCustomer.
// ============================================================

UserModel? _findPublicUserLocally(
  String guardianMoxId,
) {
  try {
    final String cleanGuardianMoxId =
        guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '🔍 [LOCAL SEARCH] guardianMoxId: '
      '$cleanGuardianMoxId',
    );

    for (final UserModel user
        in StorageService.registeredUsers) {
      final String userGuardianMoxId =
          (user.guardianMoxId ?? '')
              .trim()
              .toUpperCase();

      // ======================================================
      // المطابقة الوحيدة
      // ======================================================

      if (userGuardianMoxId ==
          cleanGuardianMoxId) {
        debugPrint(
          '✅ [LOCAL SEARCH] MATCH',
        );

        debugPrint(
          '👤 [LOCAL SEARCH] العميل: ${user.name}',
        );

        debugPrint(
          '🆔 [LOCAL SEARCH] guardianMoxId: '
          '$userGuardianMoxId',
        );

        return user;
      }
    }
  } catch (e) {
    debugPrint(
      '❌ [LOCAL SEARCH] $e',
    );
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

Future<UserModel?> _findPublicUserFromCloud(
  String guardianMoxId,
) async {
  try {
    final String cleanGuardianMoxId =
        guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '☁️ [CLOUD SEARCH] البحث عن guardianMoxId: '
      '$cleanGuardianMoxId',
    );

    // ========================================================
    // Google Apps Script
    // ========================================================

    const String scriptUrl =
        'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

    // ========================================================
    // طلب جميع العملاء
    // ========================================================

    final Uri uri = Uri.parse(
      scriptUrl,
    ).replace(
      queryParameters: {
        'action': 'getAll',
      },
    );

    final http.Response response =
        await http
            .get(uri)
            .timeout(
              const Duration(seconds: 12),
            );

    debugPrint(
      '☁️ [CLOUD SEARCH] HTTP: '
      '${response.statusCode}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        '❌ [CLOUD SEARCH] HTTP ERROR '
        '${response.statusCode}',
      );

      return null;
    }

    // ========================================================
    // قراءة JSON
    // ========================================================

    final dynamic decoded =
        jsonDecode(response.body);

    if (decoded is! List) {
      debugPrint(
        '❌ [CLOUD SEARCH] الرد ليس List',
      );

      return null;
    }

    debugPrint(
      '☁️ [CLOUD SEARCH] عدد السجلات: '
      '${decoded.length}',
    );

    // ========================================================
    // البحث في العملاء
    // ========================================================

    for (final dynamic item in decoded) {
      try {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map =
            Map<String, dynamic>.from(item);

        // ====================================================
        // قراءة guardianMoxId فقط
        // ====================================================

        final String rowGuardianMoxId =
            map['guardianMoxId']
                    ?.toString()
                    .trim()
                    .toUpperCase() ??
                '';

        // ====================================================
        // لا يوجد guardianMoxId
        // ====================================================

        if (!_isValidGuardianMoxId(
          rowGuardianMoxId,
        )) {
          continue;
        }

        // ====================================================
        // المطابقة
        //
        // guardianMoxId فقط
        // ====================================================

        if (rowGuardianMoxId !=
            cleanGuardianMoxId) {
          continue;
        }

        debugPrint(
          '✅ [CLOUD SEARCH] MATCH',
        );

        debugPrint(
          '👤 [CLOUD SEARCH] العميل: '
          '${map['name'] ?? ''}',
        );

        debugPrint(
          '🆔 [CLOUD SEARCH] guardianMoxId: '
          '$rowGuardianMoxId',
        );

        // ====================================================
        // تحويل إلى UserModel
        // ====================================================

        final UserModel user =
            UserModel.fromJson(map);

        // ====================================================
        // تحديث النسخة المحلية
        //
        // هنا نستخدم moxId فقط كمفتاح داخلي
        // لتحديث السجل المحلي.
        //
        // هذا لا يعني أنه مستخدم في رابط المتجر.
        // ====================================================

        final int index =
            StorageService.registeredUsers
                .indexWhere(
          (u) {
            final String localGuardian =
                (u.guardianMoxId ?? '')
                    .trim()
                    .toUpperCase();

            return localGuardian ==
                rowGuardianMoxId;
          },
        );

        if (index == -1) {
          StorageService.registeredUsers
              .add(user);
        } else {
          StorageService.registeredUsers[index] =
              user;
        }

        debugPrint(
          '💾 [CLOUD SEARCH] '
          'تم تحديث النسخة المحلية',
        );

        return user;
      } catch (e) {
        debugPrint(
          '⚠️ [CLOUD SEARCH] سجل غير صالح: $e',
        );
      }
    }

    debugPrint(
      '⚠️ [CLOUD SEARCH] '
      'لم يتم العثور على guardianMoxId: '
      '$cleanGuardianMoxId',
    );
  } catch (e) {
    debugPrint(
      '❌ [CLOUD SEARCH] $e',
    );
  }

  return null;
}

// ============================================================
// MY APP
// ============================================================

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.initialScreen,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'MOX Digital',

      theme: ThemeData(
        primaryColor:
            const Color(0xFF28A9CC),

        scaffoldBackgroundColor:
            Colors.white,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(0xFF28A9CC),

          primary:
              const Color(0xFF28A9CC),

          surface:
              Colors.white,
        ),

        useMaterial3: true,

        fontFamily: 'Cairo',
      ),

      home: initialScreen,
    );
  }
}