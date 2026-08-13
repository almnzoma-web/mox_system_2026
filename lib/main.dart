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
// نظام روابط المتاجر العامة
//
// الرابط المعتمد:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// مهم جداً:
//
// moxId
// = الرقم التلقائي للعميل عند التسجيل
//
// guardianMoxId
// = هوية MOX اليدوية الخاصة بالمتجر
//
// الرابط العام يعتمد على guardianMoxId فقط.
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // WEB URL STRATEGY
  //
  // إزالة #
  //
  // الرابط سيكون:
  //
  // /store/MOX249-00010001
  //
  // وليس:
  //
  // /#/?
  // ==========================================================

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ==========================================================
  // تحميل المستخدمين
  // ==========================================================

  try {
    await StorageService.loadUsers();

    debugPrint('✅ [Storage] تم تحميل المستخدمين');
    debugPrint(
      '📦 [Storage] عدد المستخدمين المحليين: '
      '${StorageService.registeredUsers.length}',
    );
  } catch (e) {
    debugPrint('❌ [Storage] خطأ في تحميل المستخدمين: $e');
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
      // قراءة رابط المتجر
      // ========================================================

      final String? publicStoreId = _getPublicStoreIdFromUrl();

      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 [MAIN] URL: ${Uri.base}');
      debugPrint('🌐 [MAIN] PATH: ${Uri.base.path}');
      debugPrint('🌐 [MAIN] PUBLIC STORE ID: $publicStoreId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      // ========================================================
      // يوجد رابط متجر عام
      // ========================================================

      if (publicStoreId != null && publicStoreId.isNotEmpty) {
        debugPrint('🏪 [Public Store] فتح المتجر: $publicStoreId');

        UserModel? foundUser;

        // ======================================================
        // 1. البحث المحلي
        // ======================================================

        foundUser = _findPublicUserLocally(publicStoreId);

        // ======================================================
        // 2. إذا لم يوجد محلياً
        //    البحث في Google Sheets
        // ======================================================

        foundUser ??= await _findPublicUserFromCloud(publicStoreId);

        // ======================================================
        // 3. وجدنا المتجر
        // ======================================================

        if (foundUser != null) {
          debugPrint('✅ [Public Store] تم العثور على المتجر بنجاح');

          debugPrint('🆔 [Public Store] moxId: ${foundUser.moxId}');

          debugPrint(
            '🔐 [Public Store] guardianMoxId: '
            '${foundUser.guardianMoxId}',
          );

          initialScreen = Scaffold(
            backgroundColor: Colors.white,
            body: StorePreviewWidget(user: foundUser, isPublicView: true),
          );
        }
        // ======================================================
        // 4. المتجر غير موجود
        // ======================================================
        else {
          debugPrint(
            '⚠️ [Public Store] لم يتم العثور على المتجر: '
            '$publicStoreId',
          );

          initialScreen = _publicStoreNotFoundScreen(publicStoreId);
        }
      }
      // ========================================================
      // لا يوجد رابط متجر عام
      //
      // مثال:
      // https://mox-2026.vercel.app/
      // ========================================================
      else {
        debugPrint('ℹ️ [MAIN] لا يوجد رابط متجر عام');

        // ------------------------------------------------------
        // فحص الجلسة المحفوظة
        // ------------------------------------------------------

        final UserModel? savedUser = await StorageService.getUser();

        if (savedUser != null) {
          debugPrint('🔐 [Remember Login] جلسة محفوظة موجودة');

          initialScreen = DashboardScreen(user: savedUser);
        } else {
          debugPrint('🔓 [Remember Login] لا توجد جلسة محفوظة');

          initialScreen = const WelcomeScreen();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [MAIN ERROR] $e');
      debugPrint('$stackTrace');

      initialScreen = const WelcomeScreen();
    }
  }

  // ==========================================================
  // تشغيل التطبيق
  // ==========================================================

  runApp(MyApp(initialScreen: initialScreen));
}

// ============================================================
// 🔗 استخراج هوية المتجر من الرابط
//
// الرابط الوحيد المعتمد:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// القيمة:
//
// MOX249-00010001
//
// هذه القيمة هي guardianMoxId
//
// لا نقرأ:
// - moxId
// - phone
// - ?mox
// - fragment
// - #
//
// ============================================================

String? _getPublicStoreIdFromUrl() {
  try {
    final Uri uri = Uri.base;

    debugPrint('🔗 [URL Parser] URI: ${uri.toString()}');

    debugPrint('🔗 [URL Parser] PATH: ${uri.path}');

    final List<String> segments = uri.pathSegments;

    debugPrint('🔗 [URL Parser] SEGMENTS: $segments');

    // ========================================================
    // نبحث عن:
    //
    // /store/
    // ========================================================

    final int storeIndex = segments.indexOf('store');

    if (storeIndex == -1) {
      debugPrint('ℹ️ [URL Parser] لا يوجد /store/ في الرابط');

      return null;
    }

    // ========================================================
    // التأكد من وجود القيمة بعد /store/
    // ========================================================

    if (segments.length <= storeIndex + 1) {
      debugPrint('⚠️ [URL Parser] /store/ موجود ولكن لا توجد هوية بعده');

      return null;
    }

    // ========================================================
    // استخراج guardianMoxId
    // ========================================================

    final String guardianMoxId = Uri.decodeComponent(
      segments[storeIndex + 1],
    ).trim();

    if (guardianMoxId.isEmpty) {
      debugPrint('⚠️ [URL Parser] guardianMoxId فارغ');

      return null;
    }

    debugPrint('🔐 [URL Parser] guardianMoxId: $guardianMoxId');

    return guardianMoxId;
  } catch (e) {
    debugPrint('❌ [URL Parser] $e');

    return null;
  }
}

// ============================================================
// 🔎 البحث المحلي
//
// مهم:
// الرابط العام يعتمد على guardianMoxId.
//
// لا نستخدم moxId هنا حتى لا يحدث خلط بين:
//
// moxId
// و
// guardianMoxId
//
// ============================================================

UserModel? _findPublicUserLocally(String guardianMoxId) {
  try {
    final String cleanId = guardianMoxId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    debugPrint('🔍 [Local Search] guardianMoxId: $cleanId');

    for (final UserModel user in StorageService.registeredUsers) {
      final String userGuardianMoxId = (user.guardianMoxId ?? '').trim();

      final String userGuardianMoxIdCustomer =
          (user.guardianMoxIdCustomer ?? '').trim();

      // ======================================================
      // المطابقة الأساسية
      // ======================================================

      if (userGuardianMoxId == cleanId) {
        debugPrint('✅ [Local Search] MATCH guardianMoxId');

        return user;
      }

      // ======================================================
      // دعم guardianMoxIdCustomer إن كان مستخدماً
      // في بنية النظام الحالية
      // ======================================================

      if (userGuardianMoxIdCustomer == cleanId) {
        debugPrint('✅ [Local Search] MATCH guardianMoxIdCustomer');

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
//
// الرابط العام = guardianMoxId
//
// moxId لا يستخدم كهوية للرابط العام.
//
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String guardianMoxId) async {
  try {
    final String cleanId = guardianMoxId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    debugPrint('');
    debugPrint('☁️ [Cloud Search] البحث عن guardianMoxId: $cleanId');

    // ========================================================
    // Google Apps Script
    // ========================================================

    const String scriptUrl =
        'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

    // ========================================================
    // طلب جميع السجلات
    // ========================================================

    final Uri uri = Uri.parse(
      scriptUrl,
    ).replace(queryParameters: {'action': 'getAll'});

    debugPrint('☁️ [Cloud Search] GET: $uri');

    // ========================================================
    // إرسال الطلب
    // ========================================================

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    debugPrint(
      '☁️ [Cloud Search] HTTP: '
      '${response.statusCode}',
    );

    // ========================================================
    // فحص HTTP
    // ========================================================

    if (response.statusCode != 200) {
      debugPrint(
        '❌ [Cloud Search] HTTP ERROR: '
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

      debugPrint(
        '📄 [Cloud Search] BODY: '
        '${response.body}',
      );

      return null;
    }

    debugPrint(
      '☁️ [Cloud Search] عدد السجلات: '
      '${decoded.length}',
    );

    // ========================================================
    // البحث داخل Google Sheets
    // ========================================================

    for (final dynamic item in decoded) {
      try {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map = Map<String, dynamic>.from(item);

        // ====================================================
        // دعم اسم العمود القديم MOXID
        // ====================================================

        if ((map['moxId'] == null || map['moxId'].toString().trim().isEmpty) &&
            map['MOXID'] != null) {
          map['moxId'] = map['MOXID'];
        }

        // ====================================================
        // قراءة البيانات
        // ====================================================

        final String moxId = map['moxId']?.toString().trim() ?? '';

        // ignore: unused_local_variable
        final String phone = map['phone']?.toString().trim() ?? '';

        final String rowGuardianMoxId =
            map['guardianMoxId']?.toString().trim() ?? '';

        final String guardianMoxIdCustomer =
            map['guardianMoxIdCustomer']?.toString().trim() ?? '';

        // ====================================================
        // DEBUG
        // ====================================================

        debugPrint(
          '🔎 [Cloud Row] '
          'moxId=$moxId | '
          'guardianMoxId=$rowGuardianMoxId',
        );

        // ====================================================
        // المطابقة
        //
        // الأولوية لـ guardianMoxId
        // ====================================================

        final bool matches =
            rowGuardianMoxId == cleanId || guardianMoxIdCustomer == cleanId;

        if (!matches) {
          continue;
        }

        debugPrint(
          '✅ [Cloud Search] MATCH '
          'guardianMoxId=$cleanId',
        );

        // ====================================================
        // تحويل إلى UserModel
        // ====================================================

        final UserModel user = UserModel.fromJson(map);

        // ====================================================
        // تحديث النسخة المحلية
        //
        // نستخدم moxId الداخلي هنا لتحديث السجل،
        // لكنه ليس هوية الرابط العام.
        // ====================================================

        final int index = StorageService.registeredUsers.indexWhere(
          (u) => u.moxId.trim() == user.moxId.trim(),
        );

        if (index == -1) {
          StorageService.registeredUsers.add(user);

          debugPrint('💾 [Cloud Search] تمت إضافة المستخدم محلياً');
        } else {
          StorageService.registeredUsers[index] = user;

          debugPrint('💾 [Cloud Search] تم تحديث المستخدم محلياً');
        }

        return user;
      } catch (e) {
        debugPrint('⚠️ [Cloud Search] صف غير صالح: $e');
      }
    }

    debugPrint(
      '⚠️ [Cloud Search] لم يتم العثور على '
      'guardianMoxId=$cleanId',
    );
  } catch (e, stackTrace) {
    debugPrint('❌ [Cloud Search] $e');

    debugPrint('❌ [Cloud Search Stack] $stackTrace');
  }

  return null;
}

// ============================================================
// ⚠️ شاشة متجر غير موجود
// ============================================================

Widget _publicStoreNotFoundScreen(String guardianMoxId) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 80,
              color: Color(0xFF28A9CC),
            ),

            const SizedBox(height: 24),

            const Text(
              'المتجر غير موجود',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              'هوية المتجر: $guardianMoxId',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 12),

            const Text(
              'تأكد من صحة رابط المتجر.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
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
