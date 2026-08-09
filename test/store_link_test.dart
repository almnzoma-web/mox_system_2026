import 'package:flutter_test/flutter_test.dart';
import 'package:mox_digital_app/screens/client_store_admin_screen.dart';

void main() {
  test('buildStoreLink uses the guardian id when available', () {
    expect(
      buildStoreLink('abc123'),
      'https://mox-2026.vercel.app/#/?mox=ABC123',
    );
  });

  test('buildStoreLink falls back to the direct id when guardian id is missing', () {
    expect(
      buildStoreLink('', fallbackMoxId: 'xyz789'),
      'https://mox-2026.vercel.app/#/?mox=XYZ789',
    );
  });

  test('buildStoreLink returns empty for invalid identifiers', () {
    expect(buildStoreLink('لم يحدد'), '');
    expect(buildStoreLink('NULL', fallbackMoxId: '   '), '');
  });
}
