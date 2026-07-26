import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // حزمة استراتيجية الروابط
import 'screens/welcome_screen.dart';
import 'data/user_data.dart';

void main() async {
  // تفعيل الربط السيادي قبل الإقلاع بالمسطرة
  WidgetsFlutterBinding.ensureInitialized();

  // فرض نظام الـ Hash بالملي لتدمير مشكلة 404 على Vercel نهائياً
  setUrlStrategy(HashUrlStrategy());

  // تحميل سجل الدولة (قاعدة البيانات المركزية) في الذاكرة بالكامل قبل فتح البوابة
  await loadUsers();

  // انطلاق المنظومة السيادية
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MOX Digital',
      theme: ThemeData(
        // الألوان السيادية للمنظومة
        primaryColor: const Color(0xFF28A9CC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28A9CC),
          primary: const Color(0xFF28A9CC),
        ),
        useMaterial3: true,
        // اعتماد خط Cairo السيادي بأمان تام دون تداخل
        fontFamily: 'Cairo',
      ),
      // البوابة السيادية الأولى للإقلاع
      home: const WelcomeScreen(),
    );
  }
}
