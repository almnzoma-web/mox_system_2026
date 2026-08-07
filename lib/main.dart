import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';

import 'screens/welcome_screen.dart';
import 'widgets/store_preview_widget.dart';
import 'services/storage_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setUrlStrategy(HashUrlStrategy());

  try {
    await StorageService.loadUsers();
  } catch (_) {}

  Widget initialScreen = const WelcomeScreen();

  if (kIsWeb) {
    try {
      final uri = Uri.base;

      String? targetMox =
          uri.queryParameters['mox'] ?? uri.queryParameters['phone'];

      // دعم الروابط التي تأتي بعد #
      if ((targetMox == null || targetMox.trim().isEmpty) && uri.hasFragment) {
        try {
          final fragmentString = uri.fragment;
          final parsedFragment = Uri.parse("http://localhost/$fragmentString");

          targetMox =
              parsedFragment.queryParameters['mox'] ??
              parsedFragment.queryParameters['phone'];
        } catch (_) {}
      }

      if (targetMox != null && targetMox.trim().isNotEmpty) {
        targetMox = targetMox.trim();

        // البحث المحلي أولاً
        UserModel? foundUser = await StorageService.getUserByPublicIdentifier(
          targetMox,
        );

        // إذا لم يوجد محلياً، يتم البحث المباشر في Google Sheets
        foundUser ??= await StorageService.getUserByPublicIdentifierFromCloud(
          targetMox,
        );

        if (foundUser != null) {
          initialScreen = Scaffold(
            backgroundColor: Colors.white,
            body: StorePreviewWidget(user: foundUser, isPublicView: true),
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
