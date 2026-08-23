import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
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
// الرابط العام:
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// الهوية المستخدمة في المتجر العام:
// guardianMoxId
//
// لا نستخدم في تحديد المتجر العام:
// moxId
// phone
// guardianMoxIdCustomer
//
// ============================================================

// ============================================================
// VERCEL STORE API
//
// Flutter
//    ↓
// Vercel /api/store
//    ↓
// Google Apps Script
//    ↓
// Google Sheets
//
// ============================================================

const String publicStoreApi =
    'https://script.google.com/macros/s/AKfycbyZopgVkCqIEQyJHVsjs1AT07MGG6swOFGgdOkwgYwvpA-UVySfUlyA_gOHr_-XtWsj/exec?action=getUserByGuardianMoxId';

// ============================================================
// APP LINKS
// ============================================================
//
// Android App Links:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// ============================================================

final AppLinks _appLinks = AppLinks();

StreamSubscription<Uri>? _appLinksSubscription;

// ============================================================
// NAVIGATOR KEY
// ============================================================
//
// نستخدمه لمعالجة App Links التي تصل والتطبيق مفتوح.
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // WEB URL STRATEGY
  // ==========================================================

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // ==========================================================
  // الشاشة الافتراضية
  // ==========================================================

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // WEB
  //
  // إذا كان الرابط:
  //
  // /store/MOX249-00010001
  //
  // نعالج المتجر العام مباشرة.
  // ==========================================================

  if (kIsWeb) {
    try {
      final Uri uri = Uri.base;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🌐 [BOOT] URI      : ${uri.toString()}');
      debugPrint('🌐 [BOOT] PATH     : ${uri.path}');
      debugPrint('🌐 [BOOT] SEGMENTS : ${uri.pathSegments}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final String? guardianMoxId = _getGuardianMoxIdFromUri(uri);

      debugPrint('🏪 [BOOT] GUARDIAN : $guardianMoxId');

      if (guardianMoxId != null) {
        initialScreen = await _loadPublicStoreScreen(guardianMoxId);
      } else {
        initialScreen = await _loadNormalApplication();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [BOOT WEB ERROR] $e');

      debugPrint('$stackTrace');

      initialScreen = const WelcomeScreen();
    }
  }
  // ==========================================================
  // ANDROID / IOS
  //
  // نقرأ الرابط الذي فتح التطبيق.
  // ==========================================================
  else {
    try {
      final Uri? initialUri = await _getInitialAppLink();

      if (initialUri != null) {
        debugPrint(
          '🔗 [BOOT APP LINK] '
          'Initial URI: $initialUri',
        );

        final String? guardianMoxId = _getGuardianMoxIdFromUri(initialUri);

        if (guardianMoxId != null) {
          debugPrint(
            '🏪 [BOOT APP LINK] '
            'Opening store: $guardianMoxId',
          );

          initialScreen = await _loadPublicStoreScreen(guardianMoxId);
        } else {
          debugPrint(
            'ℹ️ [BOOT APP LINK] '
            'الرابط ليس رابط متجر عام',
          );

          initialScreen = await _loadNormalApplication();
        }
      } else {
        debugPrint(
          'ℹ️ [BOOT APP LINK] '
          'لا يوجد رابط ابتدائي',
        );

        initialScreen = await _loadNormalApplication();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [BOOT MOBILE ERROR] $e');

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
// INITIAL APP LINK
// ============================================================
//
// الرابط الذي فتح التطبيق لأول مرة.
// ============================================================

Future<Uri?> _getInitialAppLink() async {
  try {
    final Uri? uri = await _appLinks.getInitialLink();

    debugPrint('🔗 [APP LINKS] Initial link: $uri');

    return uri;
  } catch (e) {
    debugPrint('❌ [APP LINKS] Initial link error: $e');

    return null;
  }
}

// ============================================================
// APP LINK STREAM
// ============================================================
//
// الروابط التي تصل والتطبيق مفتوح.
// ============================================================

void _startAppLinksListener(BuildContext context) {
  if (kIsWeb) {
    return;
  }

  _appLinksSubscription?.cancel();

  _appLinksSubscription = _appLinks.uriLinkStream.listen(
    (Uri uri) async {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      debugPrint('🔗 [APP LINKS STREAM] URI: $uri');

      debugPrint('🔗 [APP LINKS STREAM] PATH: ${uri.path}');

      debugPrint(
        '🔗 [APP LINKS STREAM] SEGMENTS: '
        '${uri.pathSegments}',
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final String? guardianMoxId = _getGuardianMoxIdFromUri(uri);

      if (guardianMoxId == null) {
        debugPrint(
          '⚠️ [APP LINKS STREAM] '
          'ليس رابط متجر صالح',
        );

        return;
      }

      debugPrint(
        '🏪 [APP LINKS STREAM] '
        'Loading: $guardianMoxId',
      );

      final Widget screen = await _loadPublicStoreScreen(guardianMoxId);

      // ======================================================
      // حماية BuildContext
      // ======================================================
      //
      // لا نستخدم BuildContext القديم بعد await.
      // ======================================================

      final NavigatorState? navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          '⚠️ [APP LINKS STREAM] '
          'Navigator غير جاهز',
        );

        return;
      }

      navigator.pushReplacement(MaterialPageRoute(builder: (_) => screen));
    },
    onError: (Object error) {
      debugPrint('❌ [APP LINKS STREAM ERROR] $error');
    },
  );
}

// ============================================================
// PUBLIC STORE SCREEN
// ============================================================
//
// مهم جدًا:
//
// لا نستخدم StorageService هنا.
// لا نحتاج تسجيل دخول.
// لا نحتاج جلسة.
// لا نحتاج المستخدم المحلي.
//
// الرابط العام:
// guardianMoxId
//
// ثم:
// Vercel → Google → UserModel
// ============================================================

Future<Widget> _loadPublicStoreScreen(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return _buildStoreNotFoundScreen(cleanGuardianMoxId);
    }

    debugPrint('🏪 [PUBLIC STORE] بدء تحميل المتجر: $cleanGuardianMoxId');

    UserModel? user;

    // 1. محاولة البحث المحلي السريع أولاً (Cache) لتفادي الـ Timeout
    try {
      await StorageService.loadUsers();
      final int index = StorageService.registeredUsers.indexWhere(
        (u) =>
            (u.guardianMoxId ?? '').trim().toUpperCase() == cleanGuardianMoxId,
      );
      if (index != -1) {
        user = StorageService.registeredUsers[index];
        debugPrint(
          '⚡ [PUBLIC STORE] تم العثور على العميل محلياً (بدون انتظار السحابة)',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [PUBLIC STORE] خطأ في القراءة المحلية: $e');
    }

    // 2. إذا لم يكن موجوداً محلياً (جهاز جديد كلياً)، نطلبه من السحابة
    if (user == null) {
      debugPrint(
        '☁️ [PUBLIC STORE] العميل غير موجود محلياً، جارٍ السحب من السحابة...',
      );
      user = await _findPublicUserFromCloud(cleanGuardianMoxId);
    }

    // 3. التحقق النهائي والعرض
    if (user != null) {
      debugPrint('✅ [PUBLIC STORE] المتجر موجود وجاهز للعرض: ${user.name}');

      // حفظه كجلسة تلقائية للجهاز
      try {
        await StorageService.saveUser(user);
      } catch (_) {}

      return _buildPublicStoreScreen(user);
    }

    return _buildStoreNotFoundScreen(cleanGuardianMoxId);
  } catch (e, stackTrace) {
    debugPrint('❌ [PUBLIC STORE ERROR] $e');
    debugPrint('$stackTrace');
    return _buildStoreNotFoundScreen(guardianMoxId);
  }
}

// ============================================================
// NORMAL APPLICATION
// ============================================================
//
// هذا الجزء فقط يستخدم جلسة المستخدم.
// ============================================================

Future<Widget> _loadNormalApplication() async {
  try {
    debugPrint(
      'ℹ️ [MAIN] '
      'لا يوجد رابط متجر عام',
    );

    await StorageService.loadUsers();

    final UserModel? savedUser = await StorageService.getUser();

    if (savedUser != null) {
      debugPrint(
        '🔐 [REMEMBER LOGIN] '
        'جلسة محفوظة موجودة',
      );

      return DashboardScreen(user: savedUser);
    }

    debugPrint(
      '🔓 [REMEMBER LOGIN] '
      'لا توجد جلسة محفوظة',
    );

    return const WelcomeScreen();
  } catch (e, stackTrace) {
    debugPrint('❌ [MAIN NORMAL ERROR] $e');

    debugPrint('$stackTrace');

    return const WelcomeScreen();
  }
}

// ============================================================
// BUILD PUBLIC STORE
// ============================================================

Widget _buildPublicStoreScreen(UserModel user) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: StorePreviewWidget(user: user, isPublicView: true),
  );
}

// ============================================================
// STORE NOT FOUND
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
// URI PARSER
// ============================================================
//
// الرابط:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// النتيجة:
//
// MOX249-00010001
// ============================================================

String? _getGuardianMoxIdFromUri(Uri uri) {
  try {
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
      '${uri.pathSegments}',
    );

    final List<String> segments = uri.pathSegments;

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
    // الجزء الأول
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
      '🏪 [URL PARSER] '
      'guardianMoxId = '
      '$guardianMoxId',
    );

    return guardianMoxId;
  } catch (e) {
    debugPrint('❌ [URL PARSER] $e');

    return null;
  }
}

// ============================================================
// VALIDATE GUARDIAN MOX ID
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
// CLOUD SEARCH
// ============================================================
//
// Flutter
// ↓
// Vercel
// ↓
// Google Apps Script
// ↓
// Google Sheets
//
// البحث الوحيد:
//
// guardianMoxId
// ============================================================

Future<UserModel?> _findPublicUserFromCloud(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    debugPrint(
      '☁️ [CLOUD SEARCH] '
      'البحث عن المتجر: '
      '$cleanGuardianMoxId',
    );

    // ========================================================
    // VERCEL API
    // ========================================================

    // بناء الرابط المباشر لجوجل مع المعرف تماماً مثل المتصفح
    final Uri uri = Uri.parse(
      'https://script.google.com/macros/s/AKfycbyZopgVkCqIEQyJHVsjs1AT07MGG6swOFGgdOkwgYwvpA-UVySfUlyA_gOHr_-XtWsj/exec?action=getUserByGuardianMoxId&guardianMoxId=$cleanGuardianMoxId',
    );

    debugPrint('🌐 [STORE API DIRECT] URL: $uri');

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
      debugPrint(
        '❌ [STORE API] '
        'الرد فارغ',
      );

      return null;
    }

    // ========================================================
    // JSON
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
        '❌ [STORE API] '
        'JSON decode error: $e',
      );

      debugPrint(
        '❌ [STORE API] '
        'RESPONSE: $body',
      );

      return null;
    }

    // ========================================================
    // RESPONSE MAP
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
    // API SUCCESS
    // ========================================================

    if (map['success'] == false) {
      debugPrint(
        '⚠️ [STORE API] '
        '${map['message'] ?? 'فشل تحميل المتجر'}',
      );

      return null;
    }

    // ========================================================
    // USER MAP
    //
    // Google / Vercel قد يعيد:
    //
    // {
    //   user: {...}
    // }
    //
    // أو:
    //
    // {
    //   data: {...}
    // }
    //
    // أو البيانات مباشرة.
    // ========================================================

    // ========================================================
    // استخراج بيانات المستخدم
    // ========================================================

    final Map<String, dynamic> userMap = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'])
        : map['data'] is Map
        ? Map<String, dynamic>.from(map['data'])
        : map;

    // ========================================================
    // guardianMoxId من المستخدم نفسه
    // ========================================================

    final String rowGuardianMoxId =
        (userMap['guardianMoxId'] ??
                userMap['GuardianMoxId'] ??
                userMap['guardian_mox_id'] ??
                map['guardianMoxId'] ??
                '')
            .toString()
            .trim()
            .toUpperCase();

    if (!_isValidGuardianMoxId(rowGuardianMoxId)) {
      debugPrint('⚠️ [STORE API] guardianMoxId المسترجع غير صالح');

      return null;
    }

    // ========================================================
    // حماية مهمة جدًا
    //
    // ID الموجود في الرابط يجب أن يطابق ID القادم من Google
    // ========================================================

    if (rowGuardianMoxId != cleanGuardianMoxId) {
      debugPrint('❌ [STORE API] guardianMoxId لا يطابق الرابط');

      debugPrint('الرابط: $cleanGuardianMoxId');

      debugPrint('البيانات: $rowGuardianMoxId');

      return null;
    }

    debugPrint('✅ [STORE API] guardianMoxId مطابق للرابط');

    debugPrint('🔍 [MAP KEYS]: ${userMap.keys.toList()}');

    debugPrint(
      '🔍 [RAW storePublishDate]: '
      '${userMap['storePublishDate'] ?? userMap['StorePublishDate']}',
    );

    // ========================================================
    // بناء UserModel
    // ========================================================

    final UserModel user = UserModel.fromJson(userMap);

    // ========================================================
    // تحديث النسخة المحلية
    //
    // هذا ليس شرطًا لفتح المتجر.
    //
    // مجرد Cache اختياري.
    // ========================================================

    try {
      final int index = StorageService.registeredUsers.indexWhere((u) {
        final String localGuardian = (u.guardianMoxId ?? '')
            .trim()
            .toUpperCase();

        return localGuardian == rowGuardianMoxId;
      });

      if (index == -1) {
        StorageService.registeredUsers.add(user);
      } else {
        StorageService.registeredUsers[index] = user;
      }

      debugPrint(
        '💾 [CLOUD SEARCH] '
        'تم تحديث Cache المحلي',
      );
    } catch (e) {
      // ======================================================
      // فشل الـ Cache لا يجب أن يمنع فتح المتجر.
      // ======================================================

      debugPrint(
        '⚠️ [CLOUD SEARCH] '
        'تعذر تحديث Cache: $e',
      );
    }

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

class MyApp extends StatefulWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  State<MyApp> createState() => _MyAppState();
}

// ============================================================
// MY APP STATE
// ============================================================

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // ========================================================
    // تشغيل مراقبة App Links
    //
    // بعد اكتمال بناء التطبيق.
    // ========================================================

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _startAppLinksListener(context);
    });
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();

    _appLinksSubscription = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      navigatorKey: navigatorKey,

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

      home: widget.initialScreen,
    );
  }
}
