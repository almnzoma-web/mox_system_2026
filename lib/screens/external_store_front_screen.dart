import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'welcome_screen.dart';

class ExternalStoreFrontScreen extends StatelessWidget {
  final UserModel? user;
  final List<Map<String, dynamic>> clientCards;
  final String? directPhone;
  final double? height;

  const ExternalStoreFrontScreen({
    super.key,
    this.user,
    this.clientCards = const [],
    this.directPhone,
    this.height,
  });

  UserModel _resolveUser() {
    if (user != null) return user!;

    String phoneToUse = directPhone ?? "0000000000";
    // تمرير المعاملات الإجبارية المطلوبة في UserModel لضمان توافق المسطرة الهندسية
    return UserModel(
      name: "العميل السيادي",
      phone: phoneToUse,
      address: "المتجر الرقمي",
      moxId: "MOX-ACTIVE",
      password: "",
      balance: 0.0,
      gender: "غير محدد",
      accountType: "external",
    );
  }

  bool _hasActiveStore(UserModel activeUser) {
    // ignore: unnecessary_nullable_for_final_variable_declarations
    final String? mox = activeUser.moxId;
    final String? gMox = activeUser.guardianMoxId;

    return (mox != null &&
            mox.trim().isNotEmpty &&
            mox != "لم يحدد" &&
            mox.toLowerCase() != 'null') ||
        (gMox != null &&
            gMox.trim().isNotEmpty &&
            gMox != "لم يحدد" &&
            gMox.toLowerCase() != 'null' &&
            !gMox.startsWith("MOX249-00010001")) ||
        activeUser.phone.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (height != null &&
        user == null &&
        directPhone == null &&
        clientCards.isEmpty) {
      return Container(height: height, color: Colors.transparent);
    }

    final UserModel resolvedUser = _resolveUser();
    final List<Map<String, dynamic>> activeCards = clientCards.isNotEmpty
        ? clientCards
        : [
            {
              'title': 'بطاقة المتجر السيادي الافتراضية',
              'description':
                  'هذه البطاقة معتمدة وجاهزة للعرض التجاري الفاخر عبر الرابط المنسوخ.',
              'price': 0.0,
              'whatsapp': resolvedUser.phone,
              'facebook': '',
            },
          ];

    final bool isStoreActive = _hasActiveStore(resolvedUser);

    Widget content = Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: Text(
          isStoreActive
              ? "متجر العميل: ${resolvedUser.name}"
              : "المتجر الرقمي السيادي",
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
                          "العميل: ${resolvedUser.name}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "رقم الهاتف: ${resolvedUser.phone}",
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
                  ...activeCards.map((card) {
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
                                          resolvedUser.phone;
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

    if (height != null) {
      return SizedBox(height: height, child: content);
    }

    return content;
  }
}
