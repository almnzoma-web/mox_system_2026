import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'welcome_screen.dart'; // الانتقال لشاشة الترحيب مباشرة عند عدم التنشيط

class ExternalStoreFrontScreen extends StatelessWidget {
  final UserModel user;
  final List<Map<String, dynamic>>
  clientCards; // استقبال البطاقات الحقيقية الـ 5 بالمسطرة

  const ExternalStoreFrontScreen({
    super.key,
    required this.user,
    this.clientCards = const [], // تمرير افتراضي فارغ لضمان عدم حدوث أي خطأ
  });

  // فحص ما إذا كان العميل قد قام بإنشاء وتنشيط متجره وأصوله الرقمية
  bool _hasActiveStore() {
    // ignore: unnecessary_nullable_for_final_variable_declarations
    final String? mox = user.moxId;
    final String? gMox = user.guardianMoxId;

    return (mox != null &&
            mox.trim().isNotEmpty &&
            mox != "لم يحدد" &&
            mox.toLowerCase() != 'null') ||
        (gMox != null &&
            gMox.trim().isNotEmpty &&
            gMox != "لم يحدد" &&
            gMox.toLowerCase() != 'null' &&
            !gMox.startsWith("MOX249-00010001"));
  }

  @override
  Widget build(BuildContext context) {
    final bool isStoreActive = _hasActiveStore() && clientCards.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: Text(
          isStoreActive ? "متجر العميل: ${user.name}" : "المتجر الرقمي السيادي",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isStoreActive
            ? ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28A9CC), Colors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🌟 الواجهة الرقمية السيادية المعتمدة",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "العميل: ${user.name}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "رقم الهاتف: ${user.phone}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "🛒 العروض والبطاقات النشطة للعميل",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // عرض البطاقات الـ 5 الحقيقية المستلمة بدقة
                  ...clientCards.map((card) {
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    card['title'] ?? "بطاقة سيادية",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${card['price'] ?? 0} ج.س",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card['description'] ?? "",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(0, 36),
                                    ),
                                    onPressed: () async {
                                      final phoneNum =
                                          card['whatsapp'] ??
                                          "249${user.phone}";
                                      final url = Uri.parse(
                                        "https://wa.me/$phoneNum",
                                      );
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      "طلب منتج/خدمة",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      minimumSize: const Size(0, 36),
                                    ),
                                    onPressed: () async {
                                      final detailsUrl = card['facebook'] ?? "";
                                      if (detailsUrl.isNotEmpty) {
                                        final url = Uri.parse(detailsUrl);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.link,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      "المزيد من التفاصيل",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.gpp_bad_rounded,
                          size: 60,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "⚠️ تنبيه سيادي فاخر",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "هذا العميل لم يقوم حتى الآن بتنشيط متجره أو دكانه وأصوله الرقمية.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // زر الدخول المباشر إلى شاشة الترحيب (WelcomeScreen)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28A9CC),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.login, color: Colors.white),
                          label: const Text(
                            "الدخول إلى التطبيق والترحيب",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
