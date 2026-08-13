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
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // WEB URL STRATEGY
  //
  // الرابط الجديد:
  // https://mox-2026.vercel.app/store/MOX249-00010001
  //
  // بدون #
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
    debugPrint('❌ [Main] خطأ في تحميل المستخدمين: $e');
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
      // استخراج معرف المتجر من الرابط
      // ========================================================

      final String? targetIdentifier = _getPublicIdentifierFromUrl();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 [MAIN] URL: ${Uri.base}');
      debugPrint('🌐 [MAIN] PATH: ${Uri.base.path}');
      debugPrint('🌐 [MAIN] STORE ID: $targetIdentifier');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ========================================================
      // متجر عام
      // ========================================================

      if (targetIdentifier != null && targetIdentifier.trim().isNotEmpty) {
        debugPrint('🔎 [Public Store] البحث عن: $targetIdentifier');

        // ------------------------------------------------------
        // 1. البحث المحلي
        // ------------------------------------------------------

        UserModel? foundUser = _findPublicUserLocally(targetIdentifier);

        // ------------------------------------------------------
        // 2. إذا لم يوجد محلياً → Google Sheets
        // ------------------------------------------------------

        foundUser ??= await _findPublicUserFromCloud(targetIdentifier);

        // ------------------------------------------------------
        // 3. تم العثور على المتجر
        // ------------------------------------------------------

        if (foundUser != null) {
          debugPrint('✅ [Public Store] تم العثور على المتجر');

          initialScreen = Scaffold(
            backgroundColor: Colors.white,
            body: StorePreviewWidget(user: foundUser, isPublicView: true),
          );
        } else {
          debugPrint(
            '⚠️ [Public Store] المتجر غير موجود: '
            '$targetIdentifier',
          );
        }
      }
      // ========================================================
      // لا يوجد رابط متجر عام
      // ========================================================
      else {
        debugPrint('ℹ️ [MAIN] لا يوجد رابط متجر عام');

        final UserModel? savedUser = await StorageService.getUser();

        if (savedUser != null) {
          debugPrint('🔐 [Remember Login] جلسة محفوظة موجودة');

          initialScreen = DashboardScreen(user: savedUser);
        } else {
          debugPrint('🔓 [Remember Login] لا توجد جلسة محفوظة');
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

  runApp(MyApp(initialScreen: initialScreen));
}

// ============================================================
// 🔗 استخراج معرف المتجر من الرابط
//
// الرابط المعتمد:
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// لا يوجد:
// #
// ?mox=
// fragment
// ============================================================

String? _getPublicIdentifierFromUrl() {
  try {
    final Uri uri = Uri.base;

    debugPrint('🔗 [URL Parser] URI: ${uri.toString()}');

    debugPrint('🔗 [URL Parser] PATH: ${uri.path}');

    // ========================================================
    // أجزاء المسار
    //
    // /store/MOX249-00010001
    //
    // تصبح:
    // ["store", "MOX249-00010001"]
    // ========================================================

    final List<String> segments = uri.pathSegments;

    debugPrint('🔗 [URL Parser] SEGMENTS: $segments');

    // ========================================================
    // البحث عن store
    // ========================================================

    final int storeIndex = segments.indexOf('store');

    if (storeIndex == -1) {
      debugPrint('ℹ️ [URL Parser] المسار لا يحتوي /store/');

      return null;
    }

    // ========================================================
    // التأكد من وجود MOX ID بعد store
    // ========================================================

    if (segments.length <= storeIndex + 1) {
      debugPrint('⚠️ [URL Parser] لا يوجد MOX ID بعد /store/');

      return null;
    }

    // ========================================================
    // استخراج MOX ID
    // ========================================================

    final String moxId = Uri.decodeComponent(segments[storeIndex + 1]).trim();

    if (moxId.isEmpty) {
      debugPrint('⚠️ [URL Parser] MOX ID فارغ');

      return null;
    }

    debugPrint('🏪 [URL Parser] MOX ID: $moxId');

    return moxId;
  } catch (e) {
    debugPrint('❌ [URL Parser] $e');

    return null;
  }
}

// ============================================================
// 🔎 البحث المحلي عن المتجر
// ============================================================

UserModel? _findPublicUserLocally(String identifier) {
  try {
    final String cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    debugPrint('🔍 [Local Search] البحث عن: $cleanIdentifier');

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
        debugPrint('✅ [Local Search] تم العثور على المستخدم');

        return user;
      }
    }
  } catch (e) {
    debugPrint('❌ [Local Search] $e');
  }

  return null;
}

// ============================================================
// ☁️ البحث في Google Sheets
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String identifier) async {
  try {
    final String cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      return null;
    }

    debugPrint(
      '☁️ [Cloud Search] البحث في Google عن: '
      '$cleanIdentifier',
    );

    // ========================================================
    // Google Apps Script
    // ========================================================

    const String scriptUrl =
        'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

    final Uri uri = Uri.parse(
      scriptUrl,
    ).replace(queryParameters: {'action': 'getAll'});

    // ========================================================
    // الطلب
    // ========================================================

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));

    debugPrint(
      '☁️ [Cloud Search] HTTP: '
      '${response.statusCode}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        '❌ [Cloud Search] HTTP ERROR '
        '${response.statusCode}',
      );

      return null;
    }

    // ========================================================
    // قراءة JSON
    // ========================================================

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      debugPrint('❌ [Cloud Search] الرد ليس List');

      return null;
    }

    debugPrint(
      '☁️ [Cloud Search] عدد السجلات: '
      '${decoded.length}',
    );

    // ========================================================
    // البحث داخل السجلات
    // ========================================================

    for (final dynamic item in decoded) {
      try {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map = Map<String, dynamic>.from(item);

        // ====================================================
        // دعم MOXID القديم
        // ====================================================

        if ((map['moxId'] == null || map['moxId'].toString().trim().isEmpty) &&
            map['MOXID'] != null) {
          map['moxId'] = map['MOXID'];
        }

        // ====================================================
        // قراءة المعرفات
        // ====================================================

        final String moxId = map['moxId']?.toString().trim() ?? '';

        final String phone = map['phone']?.toString().trim() ?? '';

        final String guardianMoxId =
            map['guardianMoxId']?.toString().trim() ?? '';

        final String guardianMoxIdCustomer =
            map['guardianMoxIdCustomer']?.toString().trim() ?? '';

        // ====================================================
        // المطابقة
        // ====================================================

        final bool matches =
            moxId == cleanIdentifier ||
            phone == cleanIdentifier ||
            guardianMoxId == cleanIdentifier ||
            guardianMoxIdCustomer == cleanIdentifier;

        if (!matches) {
          continue;
        }

        debugPrint(
          '✅ [Cloud Search] MATCH: '
          '$cleanIdentifier',
        );

        // ====================================================
        // تحويل إلى UserModel
        // ====================================================

        final UserModel user = UserModel.fromJson(map);

        // ====================================================
        // تحديث التخزين المحلي
        // ====================================================

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

        debugPrint('💾 [Cloud Search] تم تحديث النسخة المحلية');

        return user;
      } catch (e) {
        debugPrint('⚠️ [Cloud Search] صف غير صالح: $e');
      }
    }

    debugPrint(
      '⚠️ [Cloud Search] لم يتم العثور على: '
      '$cleanIdentifier',
    );
  } catch (e) {
    debugPrint('❌ [Cloud Search] $e');
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
