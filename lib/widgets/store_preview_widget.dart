import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../models/marketing_card.dart';

class StorePreviewWidget extends StatelessWidget {
  final UserModel user;

  final List<Map<String, dynamic>> allCards;
  final Map<String, bool> activeStatus;

  final bool isPublicView;

  const StorePreviewWidget({
    super.key,

    required this.user,

    this.allCards = const [],

    this.activeStatus = const {},

    this.isPublicView = false,
  });

  // ============================================================
  // STORE PUBLISH DATE
  // ============================================================

  // ignore: unused_element
  DateTime? _getPublishDate() {
    final value = user.storePublishDate?.trim() ?? '';

    if (value.isEmpty || value == 'null') {
      return null;
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // STORE ACTIVATION DATE
  //
  // الأولوية:
  // 1. storePublishDate
  // 2. activationDate
  // ============================================================

  DateTime? _getActivationDate() {
    final String publishDate = user.storePublishDate?.trim() ?? '';

    if (publishDate.isNotEmpty && publishDate.toLowerCase() != 'null') {
      final DateTime? parsed = DateTime.tryParse(publishDate);

      if (parsed != null) {
        return parsed;
      }
    }

    final String activationDate = user.activationDate?.trim() ?? '';

    if (activationDate.isNotEmpty && activationDate.toLowerCase() != 'null') {
      final DateTime? parsed = DateTime.tryParse(activationDate);

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  // ============================================================
  // EXPIRY DATE
  // ============================================================

  DateTime? _getExpiryDate() {
    final DateTime? activationDate = _getActivationDate();

    if (activationDate == null) {
      return null;
    }

    return activationDate.add(const Duration(days: 365));
  }

  // ============================================================
  // REMAINING DAYS
  // ============================================================

  int _getRemainingDays() {
    final DateTime? expiryDate = _getExpiryDate();

    if (expiryDate == null) {
      return 0;
    }

    final Duration difference = expiryDate.difference(DateTime.now());

    if (difference.isNegative) {
      return 0;
    }

    return difference.inDays;
  }

  // ============================================================
  // STORE STATUS
  // ============================================================

  String _getStoreStatus() {
    final DateTime? activationDate = _getActivationDate();

    // لا يوجد أي تاريخ تفعيل
    if (activationDate == null) {
      return 'غير مفعّل';
    }

    final DateTime? expiryDate = _getExpiryDate();

    if (expiryDate == null) {
      return 'غير مفعّل';
    }

    if (!DateTime.now().isBefore(expiryDate)) {
      return 'منتهي';
    }

    return 'نشط';
  }
  // ============================================================
  // PUBLIC CARDS
  // ============================================================

  List<MarketingCard> _getPublicCards() {
    return user.myAssets.where((card) => card.isApproved).toList();
  }

  // ============================================================
  // WHATSAPP
  // ============================================================

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.isEmpty) {
      cleanPhone =
          user.customWhatsApp?.replaceAll(RegExp(r'[^\d]'), '') ??
          user.phone.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleanPhone.isEmpty) {
      return;
    }

    final url = Uri.parse('https://wa.me/$cleanPhone');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ============================================================
  // FACEBOOK
  // ============================================================

  Future<void> _openFacebook(String urlString) async {
    if (urlString.trim().isEmpty) {
      return;
    }

    final url = Uri.tryParse(urlString.trim());

    if (url == null) {
      return;
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ============================================================
  // CARD ICON
  // ============================================================

  Widget _buildCardIcon(MarketingCard card) {
    final key = MarketingCard.normalizeIconKey(card.iconKey);

    final symbol = MarketingCard.iconSymbols[key] ?? '⭐';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF28A9CC).withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: const Color(0xFF28A9CC).withValues(alpha: 0.20),
        ),
      ),

      alignment: Alignment.center,

      child: Text(symbol, style: const TextStyle(fontSize: 25)),
    );
  }

  // ============================================================
  // STORE CONTENT
  // ============================================================

  Widget _buildStoreContent(
    BuildContext context,
    List<MarketingCard> publicCards,
  ) {
    final remainingDays = _getRemainingDays();

    final storeStatus = _getStoreStatus();

    final isExpired = storeStatus == 'منتهي';

    final isNotActivated = storeStatus == 'غير مفعّل';

    return Directionality(
      textDirection: TextDirection.rtl,

      child: Container(
        color: Colors.white,

        child: Column(
          children: [
            // ==================================================
            // STORE HEADER
            // ==================================================
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
                          user.name.isNotEmpty ? user.name : 'المتجر الرقمي',

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
                      'المجال: ${user.address}',

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

            // ==================================================
            // STORE STATUS
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),

                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.red.shade50
                      : isNotActivated
                      ? Colors.orange.shade50
                      : Colors.indigo.shade50,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const Text(
                      'حالة المتجر:',

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
                        color: isExpired
                            ? Colors.red
                            : isNotActivated
                            ? Colors.orange
                            : const Color(0xFF28A9CC),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        isExpired
                            ? 'منتهي'
                            : isNotActivated
                            ? 'غير مفعّل'
                            : 'متبقي $remainingDays يوم',

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

            // ==================================================
            // WHATSAPP
            // ==================================================
            Padding(
              padding: const EdgeInsets.all(16),

              child: SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  onPressed: isExpired || isNotActivated
                      ? null
                      : () => _openWhatsApp(user.customWhatsApp ?? user.phone),

                  icon: const Icon(Icons.chat, color: Colors.green, size: 18),

                  label: const Text(
                    'واتساب المتجر',

                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ),
            ),

            // ==================================================
            // PRODUCTS TITLE
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Align(
                alignment: Alignment.centerRight,

                child: const Text(
                  '🛒 المنتجات والخدمات',

                  style: TextStyle(
                    fontWeight: FontWeight.bold,

                    fontSize: 15,

                    color: Color(0xFF1B6B80),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // EXPIRED / NOT ACTIVE
            // ==================================================
            if (isExpired || isNotActivated)
              Padding(
                padding: const EdgeInsets.all(30),

                child: Column(
                  children: [
                    Icon(
                      isExpired
                          ? Icons.lock_clock_outlined
                          : Icons.storefront_outlined,

                      size: 48,

                      color: Colors.grey,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      isExpired
                          ? 'انتهت مدة المتجر. يرجى تجديد الاشتراك لإعادة نشر المنتجات.'
                          : 'المتجر غير مفعّل حالياً.',

                      textAlign: TextAlign.center,

                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            // ==================================================
            // NO CARDS
            // ==================================================
            else if (publicCards.isEmpty)
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
                      'لا توجد منتجات أو خدمات منشورة حالياً.',

                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            // ==================================================
            // CARDS
            // ==================================================
            else
              ListView.builder(
                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                padding: const EdgeInsets.symmetric(horizontal: 16),

                itemCount: publicCards.length,

                itemBuilder: (context, index) {
                  final card = publicCards[index];

                  final whatsapp = card.whatsapp.isNotEmpty
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
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              _buildCardIcon(card),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      card.title.isNotEmpty
                                          ? card.title
                                          : 'منتج أو خدمة',

                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,

                                        fontSize: 15,

                                        color: Color(0xFF1B6B80),
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Row(
                                      children: [
                                        Text(
                                          card.iconSymbol,

                                          style: const TextStyle(fontSize: 12),
                                        ),

                                        const SizedBox(width: 4),

                                        Text(
                                          card.iconLabel,

                                          style: const TextStyle(
                                            color: Colors.grey,

                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (card.price > 0)
                                Text(
                                  '${card.price}',

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,

                                    fontSize: 13,

                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),

                          if (card.category.isNotEmpty) ...[
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,

                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF28A9CC,
                                ).withValues(alpha: 0.08),

                                borderRadius: BorderRadius.circular(20),
                              ),

                              child: Text(
                                card.category,

                                style: const TextStyle(
                                  color: Color(0xFF1B6B80),

                                  fontSize: 10,

                                  fontWeight: FontWeight.bold,
                                ),
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
                                    'طلب عبر واتساب',

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
                                  tooltip: 'فيسبوك',

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
              'MOX Digital App • المنظومة أونلاين',

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

  // ============================================================
  // PRIVATE PREVIEW
  // ============================================================

  Widget _buildPrivatePreview(BuildContext context) {
    final cards = user.myAssets.where((card) => card.isApproved).toList();

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
                        'معاينة المتجر الرقمي السيادي',

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // العرض العام
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
