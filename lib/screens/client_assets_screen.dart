import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'welcome_screen.dart'; // أو شاشة الدخول الرئيسية حسب مسارك

class ClientAssetsScreen extends StatefulWidget {
  final UserModel user;
  const ClientAssetsScreen({super.key, required this.user});

  @override
  State<ClientAssetsScreen> createState() => _ClientAssetsScreenState();
}

class _ClientAssetsScreenState extends State<ClientAssetsScreen> {
  // قائمة البطاقات الـ 5 الوهمية أو المستلمة من نموذج العميل
  final List<Map<String, dynamic>> _clientCards = List.generate(
    5,
    (index) => {
      'title': 'بطاقة المتجر الرقمي رقم ${index + 1}',
      'description':
          'هذا وصف تفصيلي لخدمات أو منتجات هذه البطاقة الرقمية السيادية داخل متجر العميل.',
      'price': (index + 1) * 5000,
      'whatsapp': '249900000000',
      'facebook': 'https://facebook.com',
      'isEditing': false,
    },
  );

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final String clientStoreUrl =
        "https://mox-2026.vercel.app/store?phone=${widget.user.phone}";

    // ignore: unnecessary_nullable_for_final_variable_declarations
    final String? mox = widget.user.moxId;
    final String? gMox = widget.user.guardianMoxId;

    final bool hasValidMoxAccess =
        (mox != null &&
            mox.trim().isNotEmpty &&
            mox != "لم يحدد" &&
            mox.toLowerCase() != 'null') ||
        (gMox != null &&
            gMox.trim().isNotEmpty &&
            gMox != "لم يحدد" &&
            gMox.toLowerCase() != 'null' &&
            !gMox.startsWith("MOX249-00010001"));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: const Text(
          "متجر العميل الرقمي",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // زر "دخول التطبيق" في الأعلى للزائر القادم عبر الرابط
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1B6B80),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.login, size: 16),
              label: const Text(
                "دخول التطبيق",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: ListView(
          children: [
            // بطاقة بيانات العميل
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.person, color: Colors.indigo),
                title: Text(
                  "👤 العميل: ${widget.user.name}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "الاسم الحقيقي: ${widget.user.name}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text("الهاتف: ${widget.user.phone}"),
                        const SizedBox(height: 4),
                        Text("العنوان: ${widget.user.address}"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // حالة الهوية السيادية
            if (!hasValidMoxAccess)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      "⚠️ لم تتم ترقية حساب العميل",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.teal, Colors.green],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "🌟 بطاقة الهوية السيادية",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "رقم MOX: ${widget.user.moxId != "لم يحدد" ? widget.user.moxId : widget.user.guardianMoxId}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            const Text(
              "🛒 بطاقات المتجر الـ 5",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 10),

            // توليد البطاقات الـ 5 (للقراءة فقط مع زر الترس للتنبيه)
            ..._clientCards.map((card) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
                              card['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                          Text(
                            "${card['price']} ج.س",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.indigo,
                              size: 20,
                            ),
                            tooltip: "تنبيه النظام",
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "هذا المتجر للعرض فقط. لتعديل البطاقات يرجى تسجيل الدخول من حسابك.",
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card['description'],
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
                                final url = Uri.parse(
                                  "https://wa.me/${card['whatsapp']}",
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
                                final url = Uri.parse(card['facebook']);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
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

            const SizedBox(height: 20),

            // زر تنشيط المتجر في الأسفل
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFF28A9CC), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // منطق تنشيط المتجر
              },
              icon: const Icon(
                Icons.verified_outlined,
                color: Color(0xFF28A9CC),
              ),
              label: const Text(
                "تنشيط المتجر",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1B6B80),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
