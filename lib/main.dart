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
// ============================================================
//
// الرابط العام:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// ============================================================
//
// الهوية المستخدمة في الرابط العام:
//
// guardianMoxId
//
// لا نستخدم:
//
// moxId
// phone
// guardianMoxIdCustomer
//
// ============================================================
//
// نظام فتح الرابط:
//
// Android
//   ↓
// Android App Links
//   ↓
// assetlinks.json
//   ↓
// app_links
//   ↓
// Flutter
//   ↓
// guardianMoxId
//   ↓
// Vercel /api/store
//   ↓
// Google Apps Script
//   ↓
// Google Sheets
//   ↓
// UserModel
//   ↓
// StorePreviewWidget
//
// ============================================================
//
// مهم جداً:
//
// الرابط العام مستقل تماماً عن جلسة تسجيل الدخول.
//
// إذا كان العميل A مسجل دخول ثم فتح رابط العميل B:
//
// الرابط B له الأولوية
// ويظهر المتجر B.
//
// ============================================================

// ============================================================
// VERCEL STORE API
// ============================================================

const String publicStoreApi = 'https://mox-2026.vercel.app/api/store';

// ============================================================
// APP LINKS
// ============================================================

final AppLinks _appLinks = AppLinks();

StreamSubscription<Uri>? _appLinkSubscription;

// ============================================================
// NAVIGATOR KEY
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
  // الحصول على الرابط الأول
  //
  // Web:
  //   Uri.base
  //
  // Android:
  //   AppLinks.getInitialLink()
  //
  // ==========================================================

  Uri? initialUri;

  try {
    if (kIsWeb) {
      initialUri = Uri.base;

      debugPrint('🌐 [BOOT] WEB URI: $initialUri');
    } else {
      initialUri = await _appLinks.getInitialLink();

      debugPrint('📱 [BOOT] INITIAL APP LINK: $initialUri');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ [BOOT INITIAL LINK ERROR] $e');

    debugPrint('$stackTrace');
  }

  // ==========================================================
  // استخراج رابط المتجر العام
  // ==========================================================

  String? publicGuardianMoxId;

  if (initialUri != null) {
    publicGuardianMoxId = _getPublicGuardianMoxIdFromUri(initialUri);
  }

  // ==========================================================
  // الشاشة الافتراضية
  // ==========================================================

  Widget initialScreen = const WelcomeScreen();

  // ==========================================================
  // PUBLIC STORE
  //
  // الرابط العام له الأولوية المطلقة.
  //
  // لا نهتم هنا:
  //
  // هل يوجد Login؟
  // هل يوجد User محفوظ؟
  // هل يوجد مستخدم محلي؟
  //
  // ==========================================================

  if (publicGuardianMoxId != null && publicGuardianMoxId.isNotEmpty) {
    try {
      final String guardianMoxId = publicGuardianMoxId;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      debugPrint('🏪 [PUBLIC STORE BOOT]');

      debugPrint('🏪 guardianMoxId: $guardianMoxId');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ========================================================
      // تحميل المتجر من السحابة
      //
      // مهم:
      //
      // لا نستخدم البحث المحلي أولاً.
      //
      // لأن الهاتف قد يحتوي جلسة عميل آخر.
      //
      // الرابط العام يجب أن يرجع المتجر الموجود في Google.
      //
      // ========================================================

      final UserModel? foundUser = await _findPublicUserFromCloud(
        guardianMoxId,
      );

      // ========================================================
      // المتجر موجود
      // ========================================================

      if (foundUser != null) {
        debugPrint('✅ [PUBLIC STORE BOOT] المتجر موجود');

        debugPrint('👤 الاسم: ${foundUser.name}');

        debugPrint(
          '🆔 guardianMoxId: '
          '${foundUser.guardianMoxId}',
        );

        debugPrint(
          '📅 storePublishDate: '
          '${foundUser.storePublishDate}',
        );

        debugPrint(
          '📅 activationDate: '
          '${foundUser.activationDate}',
        );

        debugPrint(
          '🧾 myAssets: '
          '${foundUser.myAssets.length}',
        );

        initialScreen = _buildPublicStoreScreen(foundUser);
      }
      // ========================================================
      // المتجر غير موجود
      // ========================================================
      else {
        debugPrint(
          '⚠️ [PUBLIC STORE BOOT] '
          'المتجر غير موجود',
        );

        initialScreen = _buildStoreNotFoundScreen(guardianMoxId);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [PUBLIC STORE BOOT ERROR] $e');

      debugPrint('$stackTrace');

      initialScreen = const WelcomeScreen();
    }
  }
  // ==========================================================
  // NORMAL APPLICATION
  //
  // يتم الوصول هنا فقط إذا لم يكن الرابط:
  //
  // /store/...
  //
  // ==========================================================
  else {
    try {
      debugPrint('ℹ️ [MAIN] لا يوجد رابط متجر عام');

      // ========================================================
      // تحميل المستخدمين المحليين
      // ========================================================

      await StorageService.loadUsers();

      // ========================================================
      // البحث عن جلسة المستخدم
      // ========================================================

      final UserModel? savedUser = await StorageService.getUser();

      // ========================================================
      // توجد جلسة
      // ========================================================

      if (savedUser != null) {
        debugPrint(
          '🔐 [REMEMBER LOGIN] '
          'جلسة محفوظة موجودة',
        );

        initialScreen = DashboardScreen(user: savedUser);
      }
      // ========================================================
      // لا توجد جلسة
      // ========================================================
      else {
        debugPrint(
          '🔓 [REMEMBER LOGIN] '
          'لا توجد جلسة محفوظة',
        );

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

  // ==========================================================
  // الاستماع للروابط الجديدة
  //
  // مهم جداً:
  //
  // هذا الجزء يعالج حالة:
  //
  // التطبيق مفتوح بالفعل
  // ثم المستخدم يضغط رابط متجر.
  //
  // ==========================================================

  if (!kIsWeb) {
    _listenToAppLinks();
  }
}

// ============================================================
// APP LINKS LISTENER
// ============================================================
//
// يعالج:
//
// التطبيق مفتوح
// أو في الخلفية
//
// ثم يصل رابط جديد.
//
// ============================================================

void _listenToAppLinks() {
  try {
    _appLinkSubscription?.cancel();

    _appLinkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        try {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          debugPrint('🔗 [APP LINK STREAM]');

          debugPrint('🔗 URI: $uri');

          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          final String? guardianMoxId = _getPublicGuardianMoxIdFromUri(uri);

          // ======================================================
          // ليس رابط متجر
          // ======================================================

          if (guardianMoxId == null) {
            debugPrint(
              'ℹ️ [APP LINK] '
              'الرابط ليس رابط متجر عام',
            );

            return;
          }

          // ======================================================
          // فتح المتجر
          // ======================================================

          await _openPublicStoreFromDeepLink(guardianMoxId);
        } catch (e, stackTrace) {
          debugPrint('❌ [APP LINK STREAM ERROR] $e');

          debugPrint('$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('❌ [APP LINK STREAM] ERROR: $error');

        debugPrint('$stackTrace');
      },
    );
  } catch (e, stackTrace) {
    debugPrint('❌ [APP LINK LISTENER ERROR] $e');

    debugPrint('$stackTrace');
  }
}

// ============================================================
// فتح متجر من رابط يصل أثناء تشغيل التطبيق
// ============================================================

Future<void> _openPublicStoreFromDeepLink(String guardianMoxId) async {
  try {
    debugPrint(
      '🏪 [DEEP LINK] تحميل المتجر: '
      '$guardianMoxId',
    );

    // ==========================================================
    // تحميل المتجر من السحابة
    // ==========================================================

    final UserModel? user = await _findPublicUserFromCloud(guardianMoxId);

    // ==========================================================
    // المتجر غير موجود
    // ==========================================================

    if (user == null) {
      debugPrint(
        '⚠️ [DEEP LINK] '
        'المتجر غير موجود',
      );

      final BuildContext? context = navigatorKey.currentState?.context;

      if (context == null) {
        return;
      }

      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _buildStoreNotFoundScreen(guardianMoxId),
        ),
      );

      return;
    }

    // ==========================================================
    // الحصول على Navigator
    // ==========================================================

    final NavigatorState? navigator = navigatorKey.currentState;

    if (navigator == null) {
      debugPrint(
        '⚠️ [DEEP LINK] '
        'Navigator غير جاهز',
      );

      return;
    }

    // ==========================================================
    // فتح المتجر العام
    //
    // نستخدم pushReplacement
    // حتى لا تتراكم روابط المتاجر فوق بعضها.
    //
    // ==========================================================

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => _buildPublicStoreScreen(user)),
    );

    debugPrint(
      '✅ [DEEP LINK] '
      'تم فتح المتجر بنجاح',
    );
  } catch (e, stackTrace) {
    debugPrint('❌ [DEEP LINK OPEN ERROR] $e');

    debugPrint('$stackTrace');
  }
}

// ============================================================
// بناء شاشة المتجر العام
// ============================================================

Widget _buildPublicStoreScreen(UserModel user) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: StorePreviewWidget(user: user, isPublicView: true),
  );
}

// ============================================================
// شاشة المتجر غير موجود
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
// استخراج guardianMoxId من URI
// ============================================================
//
// الرابط:
//
// https://mox-2026.vercel.app/store/MOX249-00010001
//
// ============================================================

String? _getPublicGuardianMoxIdFromUri(Uri uri) {
  try {
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
// التحقق من guardianMoxId
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
// البحث السحابي للمتجر العام
// ============================================================
//
// الرابط العام يعتمد على:
//
// guardianMoxId
//
// Flutter
//    ↓
// Vercel
//    ↓
// Google Apps Script
//    ↓
// Google Sheets
//
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

    final Uri uri = Uri.parse(
      publicStoreApi,
    ).replace(queryParameters: {'guardianMoxId': cleanGuardianMoxId});

    debugPrint('🌐 [STORE API] URL: $uri');

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

    // ========================================================
    // EMPTY RESPONSE
    // ========================================================

    if (response.body.trim().isEmpty) {
      debugPrint('❌ [STORE API] الرد فارغ');

      return null;
    }

    // ========================================================
    // JSON
    // ========================================================

    final String body = response.body.trim();

    // ========================================================
    // حماية HTML
    // ========================================================

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<HTML')) {
      debugPrint(
        '❌ [STORE API] '
        'الرد HTML وليس JSON',
      );

      return null;
    }

    // ========================================================
    // JSON DECODE
    // ========================================================

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (e) {
      debugPrint(
        '❌ [STORE API] '
        'JSON decode error: $e',
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
    // success:false
    // ========================================================

    if (map['success'] == false) {
      debugPrint(
        '⚠️ [STORE API] '
        '${map['message'] ?? 'فشل تحميل المتجر'}',
      );

      return null;
    }

    // ========================================================
    // تحديد مكان بيانات المستخدم
    //
    // Google / Vercel يمكن أن يعيدا:
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
    //
    // ========================================================

    final Map<String, dynamic> userMap = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'])
        : (map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map);

    // ========================================================
    // التحقق من guardianMoxId
    //
    // مهم أمنياً:
    //
    // لا نقبل بيانات مختلفة عن الرابط.
    //
    // ========================================================

    final String rowGuardianMoxId =
        (userMap['guardianMoxId'] ??
                userMap['GuardianMoxId'] ??
                userMap['guardian_mox_id'] ??
                '')
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

      debugPrint(
        'الرابط: '
        '$cleanGuardianMoxId',
      );

      debugPrint(
        'البيانات: '
        '$rowGuardianMoxId',
      );

      return null;
    }

    // ========================================================
    // DEBUG
    // ========================================================

    debugPrint(
      '🔍 [MAP KEYS]: '
      '${userMap.keys.toList()}',
    );

    debugPrint(
      '🔍 [RAW storePublishDate]: '
      '${userMap['storePublishDate'] ?? userMap['StorePublishDate'] ?? userMap['STORE_PUBLISH_DATE']}',
    );

    debugPrint(
      '🔍 [RAW activationDate]: '
      '${userMap['activationDate'] ?? userMap['ActivationDate'] ?? userMap['ACTIVATION_DATE']}',
    );

    // ========================================================
    // بناء UserModel
    // ========================================================

    final UserModel user = UserModel.fromJson(userMap);

    // ========================================================
    // DEBUG USER
    // ========================================================

    debugPrint(
      '✅ [CLOUD SEARCH] '
      'MATCH العميل: '
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
      '📅 [CLOUD SEARCH] activationDate: '
      '${user.activationDate}',
    );

    debugPrint(
      '🧾 [CLOUD SEARCH] myAssets: '
      '${user.myAssets.length}',
    );

    // ========================================================
    // تحديث النسخة المحلية
    //
    // هذا Cache فقط.
    //
    // لا نستخدمه لتحديد المتجر قبل البحث السحابي.
    //
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
        'تم تحديث النسخة المحلية للعميل',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [CLOUD CACHE] '
        'فشل تحديث النسخة المحلية: $e',
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

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'MOX Digital App',

      navigatorKey: navigatorKey,

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
