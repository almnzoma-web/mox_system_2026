import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/welcome_screen.dart';
import 'screens/external_store_front_screen.dart'; // شاشة متجر العميل الخارجي
import 'data/user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تفعيل استراتيجية الروابط النظيفة أو الـ Hash لضمان توافقية Vercel
  setUrlStrategy(HashUrlStrategy());

  // تحميل سجل الدولة (قاعدة البيانات المركزية)
  await loadUsers();

  // فحص ما إذا كان الرابط يحتوي على باراميتر متجر (mox أو phone) للزوار الخارجيين
  Widget initialScreen = const WelcomeScreen();

  if (kIsWeb) {
    try {
      final uri = Uri.base;
      // التحقق من وجود معرف المتجر في الرابط (سواء في الـ queryParameters أو الـ fragment)
      String? targetMox =
          uri.queryParameters['mox'] ?? uri.queryParameters['phone'];

      // إذا كان هناك محاولة وصول لرابط متجر مباشر، نوجه الزائر لمتجر العميل مباشرة دون تمريره بشاشة الترحيب
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
      // التوجيه الذكي للبوابة الأولى بناءً على حالة الرابط
      home: initialScreen,
    );
  }
}
