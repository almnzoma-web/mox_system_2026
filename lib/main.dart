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
// MAIN - GOOGLE AUTHORITATIVE PUBLIC STORE
// ============================================================

const String publicStoreApi =
    'https://script.google.com/macros/s/AKfycbxvpSQ4lKhKkakGQ8jUGSUppC2Q5AIF5dzdWG-mbb99daQx_neMzlhzmPbCBZEYnUfS/exec?action=getByGuardianMoxId';

// ============================================================
// APP LINKS
// ============================================================

final AppLinks _appLinks = AppLinks();
StreamSubscription<Uri>? _appLinksSubscription;

// ============================================================
// NAVIGATOR KEY
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  Widget initialScreen = const WelcomeScreen();

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
  } else {
    try {
      final Uri? initialUri = await _getInitialAppLink();

      if (initialUri != null) {
        debugPrint('🔗 [BOOT APP LINK] Initial URI: $initialUri');

        final String? guardianMoxId = _getGuardianMoxIdFromUri(initialUri);

        if (guardianMoxId != null) {
          debugPrint('🏪 [BOOT APP LINK] Opening store: $guardianMoxId');
          initialScreen = await _loadPublicStoreScreen(guardianMoxId);
        } else {
          debugPrint('ℹ️ [BOOT APP LINK] الرابط ليس رابط متجر عام');
          initialScreen = await _loadNormalApplication();
        }
      } else {
        debugPrint('ℹ️ [BOOT APP LINK] لا يوجد رابط ابتدائي');
        initialScreen = await _loadNormalApplication();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [BOOT MOBILE ERROR] $e');
      debugPrint('$stackTrace');
      initialScreen = const WelcomeScreen();
    }
  }

  debugPrint('🚀 [BOOT] تشغيل التطبيق...');
  debugPrint('🚀 [BOOT] initialScreen: ${initialScreen.runtimeType}');

  runApp(MyApp(initialScreen: initialScreen));
}

// ============================================================
// INITIAL APP LINK
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

void _startAppLinksListener(BuildContext context) {
  if (kIsWeb) return;

  _appLinksSubscription?.cancel();

  _appLinksSubscription = _appLinks.uriLinkStream.listen(
    (Uri uri) async {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔗 [APP LINKS STREAM] URI: $uri');
      debugPrint('🔗 [APP LINKS STREAM] PATH: ${uri.path}');
      debugPrint('🔗 [APP LINKS STREAM] SEGMENTS: ${uri.pathSegments}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final String? guardianMoxId = _getGuardianMoxIdFromUri(uri);

      if (guardianMoxId == null) {
        debugPrint('⚠️ [APP LINKS STREAM] ليس رابط متجر صالح');
        return;
      }

      debugPrint('🏪 [APP LINKS STREAM] Loading: $guardianMoxId');

      final Widget screen = await _loadPublicStoreScreen(guardianMoxId);

      final NavigatorState? navigator = navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('⚠️ [APP LINKS STREAM] Navigator غير جاهز');
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

Future<Widget> _loadPublicStoreScreen(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return _buildStoreNotFoundScreen(cleanGuardianMoxId);
    }

    debugPrint(
      '🏪 [PUBLIC STORE] بدء تحميل المتجر من Google: $cleanGuardianMoxId',
    );

    final UserModel? user = await _findPublicUserFromGoogle(cleanGuardianMoxId);

    if (user != null) {
      debugPrint('✅ [PUBLIC STORE] المتجر موجود وجاهز للعرض: ${user.name}');

      try {
        await StorageService.ensureLoaded();

        final int index = StorageService.registeredUsers.indexWhere((
          localUser,
        ) {
          final String localGuardian = (localUser.guardianMoxId ?? '')
              .trim()
              .toUpperCase();
          return localGuardian == cleanGuardianMoxId;
        });

        if (index == -1) {
          StorageService.registeredUsers.add(user);
        } else {
          StorageService.registeredUsers[index] = user;
        }

        debugPrint('💾 [PUBLIC STORE] تم تحديث Local Cache');
      } catch (e) {
        debugPrint('⚠️ [PUBLIC STORE] تعذر تحديث Local Cache: $e');
      }

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

Future<Widget> _loadNormalApplication() async {
  try {
    debugPrint('ℹ️ [MAIN] لا يوجد رابط متجر عام');

    await StorageService.loadUsers();

    final UserModel? savedUser = await StorageService.getUser();

    if (savedUser != null) {
      debugPrint('🔐 [REMEMBER LOGIN] جلسة محفوظة موجودة');
      return DashboardScreen(user: savedUser);
    }

    debugPrint('🔓 [REMEMBER LOGIN] لا توجد جلسة محفوظة');
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
// URI PARSER (محصن لتجنب مشاكل الفراغات والشرطة المائلة)
// ============================================================

String? _getGuardianMoxIdFromUri(Uri uri) {
  try {
    debugPrint('🔗 [URL PARSER] URI: ${uri.toString()}');
    debugPrint('🔗 [URL PARSER] PATH: ${uri.path}');
    debugPrint('🔗 [URL PARSER] SEGMENTS: ${uri.pathSegments}');

    // تصفية الأجزاء الفارغة لتجنب مشاكل الـ Trailing Slash (مثل /store/ID/)
    final List<String> segments = uri.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (segments.length != 2) {
      debugPrint(
        'ℹ️ [URL PARSER] المسار ليس رابط متجر كامل (عدد الأجزاء غير متطابق: ${segments.length})',
      );
      return null;
    }

    if (segments[0].trim().toLowerCase() != 'store') {
      debugPrint('ℹ️ [URL PARSER] المسار لا يبدأ بـ /store/');
      return null;
    }

    final String guardianMoxId = Uri.decodeComponent(
      segments[1],
    ).trim().toUpperCase();

    if (!_isValidGuardianMoxId(guardianMoxId)) {
      debugPrint('⚠️ [URL PARSER] guardianMoxId غير صالح: $guardianMoxId');
      return null;
    }

    debugPrint('🏪 [URL PARSER] guardianMoxId = $guardianMoxId');
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

  if (normalized.isEmpty ||
      normalized == 'NULL' ||
      normalized == 'UNDEFINED' ||
      normalized == 'N/A' ||
      normalized == 'لم يحدد') {
    return false;
  }

  final RegExp guardianPattern = RegExp(r'^MOX\d+-\d+$');
  return guardianPattern.hasMatch(normalized);
}

// ============================================================
// CLOUD SEARCH - GOOGLE DIRECT
// ============================================================

Future<UserModel?> _findPublicUserFromGoogle(String guardianMoxId) async {
  try {
    final String cleanGuardianMoxId = guardianMoxId.trim().toUpperCase();

    if (!_isValidGuardianMoxId(cleanGuardianMoxId)) {
      return null;
    }

    final Uri uri = Uri.parse(publicStoreApi).replace(
      queryParameters: {
        'action': 'getByGuardianMoxId',
        'guardianMoxId': cleanGuardianMoxId,
      },
    );

    debugPrint('🌐 [GOOGLE PUBLIC STORE] GET: $uri');

    final http.Response response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    debugPrint('🌐 [GOOGLE PUBLIC STORE] HTTP: ${response.statusCode}');
    debugPrint('🌐 [GOOGLE PUBLIC STORE] BODY LENGTH: ${response.body.length}');

    if (response.statusCode != 200) {
      debugPrint('❌ [GOOGLE PUBLIC STORE] HTTP ERROR: ${response.statusCode}');
      return null;
    }

    final String body = response.body.trim();
    if (body.isEmpty) return null;

    final String lowerBody = body.toLowerCase();
    if (lowerBody.startsWith('<!doctype') ||
        lowerBody.startsWith('<html') ||
        lowerBody.contains('<html')) {
      debugPrint('❌ [GOOGLE PUBLIC STORE] الرد HTML وليس JSON');
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      debugPrint('❌ [GOOGLE PUBLIC STORE] JSON decode error: $e');
      return null;
    }

    if (decoded is! Map) return null;

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

    final String status = map['status']?.toString().trim().toLowerCase() ?? '';
    final bool success =
        map['success'] == true || map['ok'] == true || status == 'success';

    if (!success) {
      debugPrint(
        '⚠️ [GOOGLE PUBLIC STORE] ${map['message'] ?? 'فشل تحميل المتجر'}',
      );
      return null;
    }

    Map<String, dynamic>? userMap;
    if (map['user'] is Map) {
      userMap = Map<String, dynamic>.from(map['user']);
    } else if (map['data'] is Map) {
      userMap = Map<String, dynamic>.from(map['data']);
    } else {
      userMap = Map<String, dynamic>.from(map);
    }

    dynamic pickValue(List<String> keys) {
      for (final String key in keys) {
        if (userMap!.containsKey(key) && userMap[key] != null) {
          return userMap[key];
        }
      }
      for (final MapEntry<String, dynamic> entry in userMap!.entries) {
        for (final String key in keys) {
          if (entry.key.trim().toLowerCase() == key.trim().toLowerCase()) {
            return entry.value;
          }
        }
      }
      return null;
    }

    final String returnedGuardian =
        pickValue([
          'guardianMoxId',
          'GuardianMoxId',
          'guardian_mox_id',
        ])?.toString().trim().toUpperCase() ??
        '';

    if (!_isValidGuardianMoxId(returnedGuardian) ||
        returnedGuardian != cleanGuardianMoxId) {
      debugPrint('❌ [GOOGLE PUBLIC STORE] guardianMoxId غير مطابق أو غير صالح');
      return null;
    }

    final Map<String, dynamic> normalizedMap = Map<String, dynamic>.from(
      userMap,
    );
    normalizedMap['guardianMoxId'] = returnedGuardian;

    final dynamic publishValue = pickValue([
      'storePublishDate',
      'StorePublishDate',
      'store_publish_date',
    ]);
    final dynamic activationValue = pickValue([
      'activationDate',
      'ActivationDate',
      'activation_date',
    ]);

    if (publishValue != null) {
      normalizedMap['storePublishDate'] = publishValue.toString();
    }
    if (activationValue != null) {
      normalizedMap['activationDate'] = activationValue.toString();
    }

    final UserModel user = UserModel.fromJson(normalizedMap);
    return user;
  } catch (e, stackTrace) {
    debugPrint('❌ [GOOGLE PUBLIC STORE ERROR] $e');
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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
