import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:http/http.dart' as http;

import 'screens/welcome_screen.dart';
import 'widgets/store_preview_widget.dart';
import 'services/storage_service.dart';
import 'models/user_model.dart';
import 'screens/dashboard_screen.dart';

// ============================================================
// MOX DIGITAL
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // Web URL Strategy
  // ----------------------------------------------------------

  setUrlStrategy(HashUrlStrategy());

  // ----------------------------------------------------------
  // تحميل المستخدمين
  // ----------------------------------------------------------

  try {
    await StorageService.loadUsers();
  } catch (e) {
    debugPrint('❌ [Main] خطأ في تحميل المستخدمين: $e');
  }

  // ----------------------------------------------------------
  // الشاشة الافتراضية
  // ----------------------------------------------------------

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // WEB
  // ==========================================================

  if (kIsWeb) {
    try {
      // ========================================================
      // 1. البحث عن متجر عام من الرابط
      // ========================================================

      final targetIdentifier = _getPublicIdentifierFromUrl();

      if (targetIdentifier != null && targetIdentifier.isNotEmpty) {
        debugPrint('🔎 [Public Store] البحث عن: $targetIdentifier');

        UserModel? foundUser = _findPublicUserLocally(targetIdentifier);

        foundUser ??= await _findPublicUserFromCloud(targetIdentifier);

        if (foundUser != null) {
          debugPrint('✅ [Public Store] تم العثور على المتجر');

          initialScreen = Scaffold(
            backgroundColor: Colors.white,

            body: StorePreviewWidget(user: foundUser, isPublicView: true),
          );
        } else {
          debugPrint('⚠️ [Public Store] المتجر غير موجود');
        }
      } else {
        // ======================================================
        // 2. لا يوجد رابط متجر عام
        //    نفحص الجلسة المحفوظة
        // ======================================================

        final savedUser = await StorageService.getUser();

        if (savedUser != null) {
          debugPrint('🔐 [Remember Login] جلسة محفوظة موجودة');

          initialScreen = DashboardScreen(user: savedUser);
        } else {
          debugPrint('🔓 [Remember Login] لا توجد جلسة محفوظة');
        }
      }
    } catch (e) {
      debugPrint('❌ [Main] $e');
    }
  }

  // ==========================================================
  // تشغيل التطبيق
  // ==========================================================

  runApp(MyApp(initialScreen: initialScreen));
}

// ============================================================
// استخراج معرف المتجر من الرابط
// ============================================================

String? _getPublicIdentifierFromUrl() {
  try {
    final uri = Uri.base;

    // --------------------------------------------------------
    // Query Parameters
    // --------------------------------------------------------

    String? identifier = uri.queryParameters['mox'];

    identifier ??= uri.queryParameters['phone'];

    identifier ??= uri.queryParameters['guardianMoxId'];

    identifier ??= uri.queryParameters['identifier'];

    if (identifier != null && identifier.trim().isNotEmpty) {
      return identifier.trim();
    }

    // --------------------------------------------------------
    // Fragment
    // --------------------------------------------------------

    final fragment = uri.fragment.trim();

    if (fragment.isEmpty) {
      return null;
    }

    // --------------------------------------------------------
    // محاولة قراءة Fragment كـ URI
    // --------------------------------------------------------

    try {
      final fragmentUri = Uri.parse('https://mox.local/$fragment');

      identifier = fragmentUri.queryParameters['mox'];

      identifier ??= fragmentUri.queryParameters['phone'];

      identifier ??= fragmentUri.queryParameters['guardianMoxId'];

      identifier ??= fragmentUri.queryParameters['identifier'];

      if (identifier != null && identifier.trim().isNotEmpty) {
        return identifier.trim();
      }
    } catch (_) {}

    // --------------------------------------------------------
    // معالجة ? داخل Fragment
    // --------------------------------------------------------

    final questionIndex = fragment.indexOf('?');

    if (questionIndex != -1 && questionIndex + 1 < fragment.length) {
      try {
        final queryString = fragment.substring(questionIndex + 1);

        final queryUri = Uri.splitQueryString(queryString);

        identifier = queryUri['mox'];

        identifier ??= queryUri['phone'];

        identifier ??= queryUri['guardianMoxId'];

        identifier ??= queryUri['identifier'];

        if (identifier != null && identifier.trim().isNotEmpty) {
          return identifier.trim();
        }
      } catch (_) {}
    }

    return null;
  } catch (e) {
    debugPrint('❌ [URL Parser] $e');

    return null;
  }
}

// ============================================================
// البحث المحلي عن المتجر
// ============================================================

UserModel? _findPublicUserLocally(String identifier) {
  try {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    for (final user in StorageService.registeredUsers) {
      final moxId = user.moxId.trim();

      final phone = user.phone.trim();

      final guardianMoxId = (user.guardianMoxId ?? '').trim();

      final guardianMoxIdCustomer = (user.guardianMoxIdCustomer ?? '').trim();

      if (moxId == cleanIdentifier ||
          phone == cleanIdentifier ||
          guardianMoxId == cleanIdentifier ||
          guardianMoxIdCustomer == cleanIdentifier) {
        return user;
      }
    }
  } catch (e) {
    debugPrint('❌ [Local Public Search] $e');
  }

  return null;
}

// ============================================================
// البحث في Google Sheets
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String identifier) async {
  try {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    const scriptUrl =
        'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

    final uri = Uri.parse(
      scriptUrl,
    ).replace(queryParameters: {'action': 'getAll'});

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint('❌ [Cloud Public Search] HTTP ${response.statusCode}');

      return null;
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      debugPrint('❌ [Cloud Public Search] الرد ليس List');

      return null;
    }

    for (final item in decoded) {
      try {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);

        // ----------------------------------------------------
        // دعم MOXID القديم
        // ----------------------------------------------------

        if ((map['moxId'] == null || map['moxId'].toString().trim().isEmpty) &&
            map['MOXID'] != null) {
          map['moxId'] = map['MOXID'];
        }

        final moxId = map['moxId']?.toString().trim() ?? '';

        final phone = map['phone']?.toString().trim() ?? '';

        final guardianMoxId = map['guardianMoxId']?.toString().trim() ?? '';

        final guardianMoxIdCustomer =
            map['guardianMoxIdCustomer']?.toString().trim() ?? '';

        final matches =
            moxId == cleanIdentifier ||
            phone == cleanIdentifier ||
            guardianMoxId == cleanIdentifier ||
            guardianMoxIdCustomer == cleanIdentifier;

        if (!matches) {
          continue;
        }

        return UserModel.fromJson(map);
      } catch (e) {
        debugPrint('⚠️ [Cloud Public Search] صف غير صالح: $e');
      }
    }
  } catch (e) {
    debugPrint('❌ [Cloud Public Search] $e');
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

      title: 'MOX Digital',

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
