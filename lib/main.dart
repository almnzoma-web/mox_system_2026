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

  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

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

      final String? targetIdentifier = _getPublicIdentifierFromUrl();

      debugPrint('🌐 [MAIN] الرابط الحالي: ${Uri.base}');

      debugPrint('🌐 [MAIN] معرف المتجر المستخرج: $targetIdentifier');

      if (targetIdentifier != null && targetIdentifier.trim().isNotEmpty) {
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
          debugPrint('⚠️ [Public Store] المتجر غير موجود: $targetIdentifier');
        }
      } else {
        // ======================================================
        // 2. لا يوجد رابط متجر عام
        //    نفحص الجلسة المحفوظة
        // ======================================================

        final UserModel? savedUser = await StorageService.getUser();

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
// 🔗 استخراج معرف المتجر من الرابط
// ============================================================

String? _getPublicIdentifierFromUrl() {
  try {
    final Uri uri = Uri.base;

    debugPrint('🔗 [URL] الرابط الحالي: ${uri.toString()}');
    debugPrint('🔗 [URL] query: ${uri.queryParameters}');

    String? clean(String? value) {
      if (value == null) return null;

      final String result = value.trim();

      if (result.isEmpty || result == 'null' || result == 'لم يحدد') {
        return null;
      }

      return result;
    }

    final Map<String, String> query = uri.queryParameters;

    String? identifier;

    identifier = clean(query['mox']);

    identifier ??= clean(query['guardianMoxId']);

    identifier ??= clean(query['moxId']);

    identifier ??= clean(query['phone']);

    identifier ??= clean(query['identifier']);

    if (identifier != null) {
      debugPrint('🔑 [URL] معرف المتجر المستخرج: $identifier');
    } else {
      debugPrint('⚠️ [URL] لم يتم العثور على معرف متجر');
    }

    return identifier;
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
    final String cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    for (final UserModel user in StorageService.registeredUsers) {
      final String moxId = user.moxId.trim();

      final String phone = user.phone.trim();

      final String guardianMoxId = (user.guardianMoxId ?? '').trim();

      final String guardianMoxIdCustomer = (user.guardianMoxIdCustomer ?? '')
          .trim();

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
    final String cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    // نفس الرابط المعتمد في StorageService.
    const String scriptUrl =
        'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

    final Uri uri = Uri.parse(
      scriptUrl,
    ).replace(queryParameters: {'action': 'getAll'});

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      debugPrint('❌ [Cloud Public Search] HTTP ${response.statusCode}');

      return null;
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      debugPrint('❌ [Cloud Public Search] الرد ليس List');

      return null;
    }

    for (final dynamic item in decoded) {
      try {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map = Map<String, dynamic>.from(item);

        // ----------------------------------------------------
        // دعم MOXID القديم
        // ----------------------------------------------------

        if ((map['moxId'] == null || map['moxId'].toString().trim().isEmpty) &&
            map['MOXID'] != null) {
          map['moxId'] = map['MOXID'];
        }

        final String moxId = map['moxId']?.toString().trim() ?? '';

        final String phone = map['phone']?.toString().trim() ?? '';

        final String guardianMoxId =
            map['guardianMoxId']?.toString().trim() ?? '';

        final String guardianMoxIdCustomer =
            map['guardianMoxIdCustomer']?.toString().trim() ?? '';

        // ----------------------------------------------------
        // التحقق من هوية المتجر
        // ----------------------------------------------------

        final bool matches =
            moxId == cleanIdentifier ||
            phone == cleanIdentifier ||
            guardianMoxId == cleanIdentifier ||
            guardianMoxIdCustomer == cleanIdentifier;

        if (!matches) {
          continue;
        }

        final UserModel user = UserModel.fromJson(map);

        // ----------------------------------------------------
        // تحديث النسخة المحلية بالنسخة القادمة
        // من Google Sheets
        // ----------------------------------------------------

        final int index = StorageService.registeredUsers.indexWhere(
          (u) =>
              u.moxId.trim() == user.moxId.trim() ||
              u.phone.trim() == user.phone.trim(),
        );

        if (index == -1) {
          StorageService.registeredUsers.add(user);
        } else {
          StorageService.registeredUsers[index] = user;
        }

        return user;
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
