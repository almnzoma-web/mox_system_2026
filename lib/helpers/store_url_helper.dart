import 'package:flutter/foundation.dart';
import 'package:mox_digital_app/models/user_model.dart';
import 'package:mox_digital_app/services/storage_service.dart';

class StoreUrlHelper {
  // ============================================================
  // 🔗 1. استخراج الهوية (guardianMoxId) من مسار المتجر (URL)
  // ============================================================
  static String? extractGuardianMoxId() {
    try {
      final List<String> segments = Uri.base.pathSegments;

      debugPrint('🔗 [URL PARSER] Segments: $segments');

      // البحث عن مقطع "store" في الرابط
      final int storeIndex = segments.indexOf('store');
      if (storeIndex != -1 && segments.length > storeIndex + 1) {
        final String extracted = segments[storeIndex + 1].trim().toUpperCase();
        debugPrint('🔗 [URL PARSER] Extracted ID: $extracted');
        return extracted;
      }
    } catch (e) {
      debugPrint('⚠️ [URL PARSER ERROR] خطأ في قراءة الرابط: $e');
    }
    return null;
  }

  // ============================================================
  // ☁️ 2. جلب بيانات المتجر المحدثة من السحابة بناءً على الهوية
  // ============================================================
  static Future<UserModel?> fetchStoreFromCloud(
    String targetGuardianMoxId,
  ) async {
    try {
      final UserModel? remoteUser = await StorageService.getUserByMoxId(
        targetGuardianMoxId,
      );
      if (remoteUser != null) {
        debugPrint(
          '✅ [LIVE SYNC] تم العثور على بيانات المتجر بنجاح من النظام السحابي.',
        );
        return remoteUser;
      }
    } catch (e) {
      debugPrint('⚠️ [LIVE SYNC ERROR] فشل التحديث السحابي للمتجر: $e');
    }
    return null;
  }
}
