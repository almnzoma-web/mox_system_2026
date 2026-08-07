// lib/services/sitemap_service.dart
import '../models/user_model.dart';

class SitemapService {
  /// توليد خريطة الموقع للزحف الأرشيفي بالمسطرة
  static String generateSitemap(List<UserModel> users, String domainUrl) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );

    // الرابط الرئيسي للمنظومة - الأولوية القصوى
    buffer.writeln('  <url>');
    buffer.writeln('    <loc>$domainUrl/</loc>');
    buffer.writeln('    <changefreq>daily</changefreq>');
    buffer.writeln('    <priority>1.0</priority>');
    buffer.writeln('  </url>');

    // روابط المتاجر النشطة
    for (var user in users) {
      if (user.moxId.isNotEmpty) {
        buffer.writeln('  <url>');
        buffer.writeln('    <loc>$domainUrl/#/?mox=${user.moxId}</loc>');
        buffer.writeln(
          '    <lastmod>${DateTime.now().toIso8601String()}</lastmod>',
        );
        buffer.writeln('    <changefreq>weekly</changefreq>');
        buffer.writeln('    <priority>0.8</priority>');
        buffer.writeln('  </url>');
      }
    }

    buffer.writeln('</urlset>');
    return buffer.toString();
  }
}
