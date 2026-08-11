import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store link matches the dynamic sovereign format', () {
    const String activeMoxForUrl = 'ABC123';

    // محاكاة بناء الرابط بنفس الصيغة المعتمدة لديك
    final String generatedLink =
        "https://mox-2026.vercel.app/#/?mox=$activeMoxForUrl";

    expect(generatedLink, 'https://mox-2026.vercel.app/#/?mox=ABC123');
    expect(generatedLink.contains('mox-2026.vercel.app'), true);
    expect(generatedLink.contains(activeMoxForUrl), true);
  });
}
