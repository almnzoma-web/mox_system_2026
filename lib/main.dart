import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/welcome_screen.dart';
import 'screens/external_store_front_screen.dart';
import 'services/storage_service.dart';

void main() async {
  // 1. ضمان استقرار ربط محرك فلاتر أولاً لمنع وميض الشاشة أو الصفحة الرمادية
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تفعيل استراتيجية الروابط لضمان توافقية Vercel والـ Hash
  setUrlStrategy(HashUrlStrategy());

  // 3. تحميل سجل الدولة (قاعدة البيانات المركزية) في الخلفية بأمان تام
  try {
    await StorageService.loadUsers();
  } catch (_) {}

  // 4. تحديد الشاشة الأولية الافتراضية لمنع أي تأخير زمني يسبب الشاشة الرمادية
  Widget initialScreen = const WelcomeScreen();

  if (kIsWeb) {
    try {
      final uri = Uri.base;

      // محاولة الالتقاط من الـ queryParameters المباشرة
      String? targetMox =
          uri.queryParameters['mox'] ?? uri.queryParameters['phone'];

      // إذا لم يتم العثور عليه، نبحث داخل الـ Fragment خلف علامة #
      if ((targetMox == null || targetMox.isEmpty) && uri.hasFragment) {
        final fragmentString = uri.fragment;
        final parsedFragment = Uri.parse("http://localhost$fragmentString");
        targetMox =
            parsedFragment.queryParameters['mox'] ??
            parsedFragment.queryParameters['phone'];
      }

      // توجيه الزائر لمتجر العميل مباشرة إذا وُجد المعرّف
      if (targetMox != null && targetMox.isNotEmpty) {
        initialScreen = ExternalStoreFrontScreen(directMoxId: targetMox);
      }
    } catch (_) {}
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MOX Digital',
      // منع ظهور الشاشة الرمادية باللون الافتراضي عبر توحيد خلفية التطبيق العامة
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
