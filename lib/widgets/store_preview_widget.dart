import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../models/marketing_card.dart';

class StorePreviewWidget extends StatelessWidget {
  final UserModel user;

  // أبقينا المتغيرين لدعم الاستدعاءات القديمة من لوحة التحكم
  final List<Map<String, dynamic>> allCards;
  final Map<String, bool> activeStatus;

  // العرض العام من الرابط
  final bool isPublicView;

  const StorePreviewWidget({
    super.key,
    required this.user,
    this.allCards = const [],
    this.activeStatus = const {},
    this.isPublicView = false,
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

  List<MarketingCard> _getPublicCards() {
    return user.myAssets.where((card) => card.isApproved).toList();
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.isEmpty) {
      cleanPhone =
          user.customWhatsApp?.replaceAll(RegExp(r'[^\d]'), '') ??
          user.phone.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleanPhone.isEmpty) return;

    final url = Uri.parse("https://wa.me/$cleanPhone");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openFacebook(String urlString) async {
    if (urlString.trim().isEmpty) return;

    Uri? url = Uri.tryParse(urlString.trim());

    if (url == null) return;

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildStoreContent(
    BuildContext context,
    List<MarketingCard> publicCards,
  ) {
    final int remainingDays = _getRemainingDays();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // رأس المتجر
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF28A9CC), Color(0xFF1B6B80)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Color(0xFF1B6B80),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.name.isNotEmpty ? user.name : "المتجر الرقمي",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (user.address.isNotEmpty)
                    Text(
                      "المجال: ${user.address}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                  if (user.storeDescription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.storeDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // العداد
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "حالة المتجر:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B6B80),
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
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
            ),

            // بيانات الاتصال
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openWhatsApp(user.customWhatsApp ?? user.phone),
                      icon: const Icon(
                        Icons.chat,
                        color: Colors.green,
                        size: 18,
                      ),
                      label: const Text(
                        "واتساب المتجر",
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // البطاقات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "🛒 المنتجات والخدمات",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1B6B80),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            if (publicCards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "لا توجد منتجات أو خدمات منشورة حالياً.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: publicCards.length,
                itemBuilder: (context, index) {
                  final card = publicCards[index];

                  final String whatsapp = card.whatsapp.isNotEmpty
                      ? card.whatsapp
                      : (user.customWhatsApp ?? user.phone);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  card.title.isNotEmpty
                                      ? card.title
                                      : "منتج أو خدمة",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF1B6B80),
                                  ),
                                ),
                              ),
                              if (card.price > 0)
                                Text(
                                  "${card.price}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),

                          if (card.category.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              card.category,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],

                          if (card.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              card.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    minimumSize: const Size(
                                      double.infinity,
                                      38,
                                    ),
                                  ),
                                  onPressed: () => _openWhatsApp(whatsapp),
                                  icon: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    "طلب عبر واتساب",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),

                              if (card.facebookUrl.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: "فيسبوك",
                                  onPressed: () =>
                                      _openFacebook(card.facebookUrl),
                                  icon: const Icon(
                                    Icons.facebook,
                                    color: Color(0xFF1877F2),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            const Text(
              "MOX Digital",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivatePreview(BuildContext context) {
    final List<MarketingCard> cards = user.myAssets
        .where((card) => card.isApproved)
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Color(0xFF28A9CC),
                        size: 22,
                      ),
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
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: _buildStoreContent(context, cards),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // العرض العام من رابط mox
    if (isPublicView) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                child: _buildStoreContent(context, _getPublicCards()),
              ),
            ),
          ),
        ),
      );
    }

    // المعاينة داخل لوحة التحكم
    return _buildPrivatePreview(context);
  }
}
