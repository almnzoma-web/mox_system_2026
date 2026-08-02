import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/welcome_screen.dart';
import 'screens/external_store_front_screen.dart'; // شاشة متجر العميل الخارجي
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تفعيل استراتيجية الروابط لضمان توافقية Vercel
  setUrlStrategy(HashUrlStrategy());

  // تحميل سجل الدولة (قاعدة البيانات المركزية) من الخزينة الدائمة حصرياً
  await StorageService.loadUsers();

  // فحص ما إذا كان الرابط يحتوي على باراميتر متجر (mox أو phone) للزوار الخارجيين
  Widget initialScreen = const WelcomeScreen();

  if (kIsWeb) {
    try {
      final uri = Uri.base;

      // 1. محاولة الالتقاط من الـ queryParameters المباشرة
      String? targetMox =
          uri.queryParameters['mox'] ?? uri.queryParameters['phone'];

      // 2. 🛡️ [الحل الجذري]: إذا لم يتم العثور عليه، نبحث داخل الـ Fragment (خلف علامة # بسبب HashUrlStrategy)
      if ((targetMox == null || targetMox.isEmpty) && uri.hasFragment) {
        final fragmentString =
            uri.fragment; // مثال: /?mox=ID-005000 أو ?mox=ID-005000
        // تحويل الـ fragment إلى Uri فرعي لتحليل البارامترات بدقة
        final parsedFragment = Uri.parse("http://localhost$fragmentString");
        targetMox =
            parsedFragment.queryParameters['mox'] ??
            parsedFragment.queryParameters['phone'];
      }

      // إذا كان هناك محاولة وصول لرابط متجر مباشر، نوجه الزائر لمتجر العميل مباشرة
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
      theme: ThemeData(
        primaryColor: const Color(0xFF28A9CC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28A9CC),
          primary: const Color(0xFF28A9CC),
        ),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: initialScreen,
    );
  }
}
