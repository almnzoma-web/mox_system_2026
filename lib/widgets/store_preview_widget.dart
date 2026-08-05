import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
// ignore: unused_import
import '../models/marketing_card.dart';

class StorePreviewWidget extends StatelessWidget {
  final UserModel user;
  final List<Map<String, dynamic>> allCards;
  final Map<String, bool> activeStatus;

  const StorePreviewWidget({
    super.key,
    required this.user,
    required this.allCards,
    required this.activeStatus,
  });

  int _getRemainingDays() {
    if (user.storePublishDate == null ||
        user.storePublishDate!.isEmpty ||
        user.storePublishDate == "null") {
      return 365;
    }
    try {
      DateTime publishDate = DateTime.parse(user.storePublishDate!);
      DateTime expiryDate = publishDate.add(const Duration(days: 365));
      int remaining = expiryDate.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 365;
    } catch (_) {
      return 365;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remainingDays = _getRemainingDays();

    // تصفية البطاقات المفعلة فقط بعلامة صح لعرضها في المعاينة المنبثقة
    final filteredCards = allCards.where((card) {
      String title = card['title'].toString();
      return activeStatus[title] == true;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس النافذة المنبثقة مع زر الإغلاق
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.visibility, color: Color(0xFF28A9CC), size: 22),
                    SizedBox(width: 8),
                    Text(
                      "معاينة المتجر الرقمي السيادي",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B6B80),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  // شريط العداد التنازلي للـ 365 يوم
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "حالة العداد الزمني:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B6B80),
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A9CC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "متبقي $remainingDays يوم",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // كارت بيانات المتجر الرئيسية
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28A9CC), Color(0xFF1B6B80)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isNotEmpty
                              ? user.name
                              : "اسم المتجر غير مدخل",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "المجال: ${user.address.isNotEmpty ? user.address : 'غير محدد'}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "هاتف الاتصال: ${user.phone}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (user.storeDescription.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            user.storeDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "🛒 البطاقات والأصول المفعلة للنشر:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1B6B80),
                    ),
                  ),
                  const SizedBox(height: 8),

                  filteredCards.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              "⚠️ لم يتم تنشيط أي بطاقة بعد (حدد مربع التنشيط لعرضها)",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredCards.length,
                          itemBuilder: (context, index) {
                            final card = filteredCards[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          card['title']?.toString() ?? "بطاقة",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF1B6B80),
                                          ),
                                        ),
                                        Text(
                                          "\$${card['price']?.toString() ?? '0.0'}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      card['description']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(
                                          double.infinity,
                                          32,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final phoneNum = user.phone;
                                        final url = Uri.parse(
                                          "https://wa.me/$phoneNum",
                                        );
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        "طلب عبر واتساب",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
