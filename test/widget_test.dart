import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mox_digital_app/main.dart';
import 'package:mox_digital_app/screens/welcome_screen.dart';

void main() {
  testWidgets('MOX Digital Initial Screen Test', (WidgetTester tester) async {
    // بناء التطبيق مع تمرير شاشة البداية الإجبارية للاختبار
    await tester.pumpWidget(const MyApp(initialScreen: WelcomeScreen()));

    // التحقق من ظهور عناصر واجهة الترحيب الأساسية بالمنظومة
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
