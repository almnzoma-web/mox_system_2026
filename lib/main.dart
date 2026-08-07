import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/welcome_screen.dart';
import 'widgets/store_preview_widget.dart';
import 'models/user_model.dart';
import 'services/storage_service.dart';
import 'data/user_data.dart';

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

      // توجيه الزائر لمتجر العميل مباشرة باستخدام StorePreviewWidget المعزز بالمسطرة
      if (targetMox != null && targetMox.isNotEmpty) {
        UserModel? foundUser;
        try {
          foundUser = registeredUsers.firstWhere(
            (u) =>
                u.moxId.trim().toUpperCase() == targetMox!.toUpperCase() ||
                (u.guardianMoxId != null &&
                    u.guardianMoxId!.trim().toUpperCase() ==
                        targetMox.toUpperCase()) ||
                u.phone.trim() == targetMox,
          );
        } catch (_) {
          foundUser = null;
        }

        if (foundUser != null) {
          final List<Map<String, dynamic>> defaultCards = [
            {
              "title": "البطاقة السيادية الأولى للمتجر",
              "description":
                  "الوصف الهندسي للبطاقة الأولى ويغطي كافة تفاصيل العرض الأساسي بالمسطرة.",
              "price": 1000.0,
              "category": "بطاقة",
            },
            {
              "title": "البطاقة السيادية الثانية للمتجر",
              "description":
                  "الوصف الهندسي للبطاقة الثانية ويغطي كافة تفاصيل العرض الفرعي بالمسطرة.",
              "price": 2000.0,
              "category": "بطاقة",
            },
            {
              "title": "القسم السيادي الثالث للمتجر",
              "description":
                  "الوصف الهندسي للقسم الثالث ويغطي تصنيفات المنتجات والخدمات الكبرى.",
              "price": 3000.0,
              "category": "قسم",
            },
            {
              "title": "الرف السيادي الرابع للمتجر",
              "description":
                  "الوصف الهندسي للرف الرابع ويغطي عرض المنتجات المميزة والخاصة.",
              "price": 4000.0,
              "category": "رف",
            },
            {
              "title": "البطاقة السيادية الخامسة للمتجر",
              "description":
                  "الوصف الهندسي للبطاقة الخامسة وتختتم حزمة الأصول التسويقية والخدمية.",
              "price": 5000.0,
              "category": "بطاقة",
            },
          ];

          Map<String, bool> activeStatus = {};
          for (var card in defaultCards) {
            activeStatus[card['title'].toString()] = true;
          }

          initialScreen = Scaffold(
            body: StorePreviewWidget(
              user: foundUser,
              allCards: defaultCards,
              activeStatus: activeStatus,
            ),
          );
        }
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
