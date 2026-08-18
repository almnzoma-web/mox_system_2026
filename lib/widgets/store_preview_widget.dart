import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

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

  // 🚀 التعديل الصحيح: جلب معرف الموكس الحقيقي من بيانات المستخدم بدلاً من القيمة الوهمية الفارغة
  String get guardianMoxId => user.guardianMoxId?.trim() ?? '';

  // ============================================================
  // STORE PUBLISH DATE
  //
  // ملاحظة مهمة:
  // التاريخ لم يعد شرطاً لعرض المتجر.
  //
  // إذا لم يوجد تاريخ نشر:
  // المتجر يعتبر نشطاً ولا يتم تعطيله.
  //
  // التاريخ يستخدم فقط لحساب انتهاء الاشتراك إذا كان موجوداً.
  // ============================================================

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
  // EXPIRY DATE
  //
  // سنة واحدة من تاريخ نشر المتجر.
  //
  // إذا لم يوجد تاريخ:
  // لا يوجد تاريخ انتهاء، وبالتالي لا نعطل المتجر.
  // ============================================================

  DateTime? _getExpiryDate() {
    final publishDate = _getPublishDate();

    if (publishDate == null) {
      return null;
    }

    return publishDate.add(const Duration(days: 365));
  }

  // ============================================================
  // SUBSCRIPTION EXPIRED
  //
  // هذه هي النقطة الوحيدة التي تحدد انتهاء الاشتراك.
  // ============================================================

  bool _isSubscriptionExpired() {
    final expiryDate = _getExpiryDate();

    // لا يوجد تاريخ = لا نعطل المتجر.
    if (expiryDate == null) {
      return false;
    }

    return !DateTime.now().isBefore(expiryDate);
  }

  // ============================================================
  // REMAINING DAYS
  //
  // -1 تعني أن المتجر ليس لديه تاريخ انتهاء محدد.
  // ============================================================

  int _getRemainingDays() {
    final expiryDate = _getExpiryDate();

    if (expiryDate == null) {
      return -1;
    }

    final difference = expiryDate.difference(DateTime.now());

    if (difference.isNegative) {
      return 0;
    }

    return difference.inDays;
  }

  // ============================================================
  // STORE STATUS
  //
  // مهم:
  // عدم وجود storePublishDate لا يعني "غير مفعّل".
  //
  // الرابط الصحيح + UserModel صحيح = المتجر يعرض.
  // الاشتراك المنتهي فقط = تعطيل الطلبات.
  // ============================================================

  String _getStoreStatus() {
    if (_isSubscriptionExpired()) {
      return 'منتهي';
    }

    return 'نشط';
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String _getStatusLabel() {
    if (_isSubscriptionExpired()) {
      return 'منتهي';
    }

    final remainingDays = _getRemainingDays();

    // لا يوجد تاريخ اشتراك محدد.
    if (remainingDays < 0) {
      return 'لم يمتلك رقم موكس';
    }

    return 'متبقي $remainingDays يوم';
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
    // الاشتراك المنتهي يمنع الطلبات فقط.
    if (_isSubscriptionExpired()) {
      return;
    }

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
  //
  // لا يتم تعطيل رابط فيسبوك بسبب انتهاء الاشتراك.
  // الاشتراك المنتهي يعطل "الطلب" فقط.
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
  // CARD ICON - الدالة السيادية المعدلة
  // ============================================================

  Widget _buildCardIcon(MarketingCard card) {
    // 1. استخراج القيمة القادمة سواء كانت category أو iconKey
    final String rawValue =
        (card.category.isNotEmpty ? card.category : card.iconKey).trim();

    // 2. جسر مطابقة النصوص العربية أو المفاتيح الإنجليزية مع الخرائط المعتمدة
    String resolvedKey = 'other';

    // مطابقة الأسماء العربية (إذا كانت مخزنة كعربي في الشيت)
    switch (rawValue) {
      case 'حقيبة تسوق':
      case 'shopping_bag':
        resolvedKey = 'shopping_bag';
        break;
      case 'متجر':
      case 'متجر وتجارة':
      case 'store':
        resolvedKey = 'store';
        break;
      case 'توصيل':
      case 'local_shipping':
        resolvedKey = 'local_shipping';
        break;
      case 'هدية':
      case 'card_giftcard':
        resolvedKey = 'card_giftcard';
        break;
      case 'نجمة':
      case 'star':
        resolvedKey = 'star';
        break;
      case 'بطاقة':
      case 'credit_card':
        resolvedKey = 'credit_card';
        break;
      case 'عرض':
      case 'local_offer':
        resolvedKey = 'local_offer';
        break;
      case 'خدمة عملاء':
      case 'headset_mic':
        resolvedKey = 'headset_mic';
        break;
      case 'قسم':
      case 'service':
        resolvedKey = 'service';
        break;
      default:
        // إذا كان المفتاح الإنجليزي موجوداً أصلاً في الخريطة
        if (MarketingCard.iconSymbols.containsKey(rawValue)) {
          resolvedKey = rawValue;
        } else {
          resolvedKey = 'other';
        }
    }

    // 3. جلب الرمز الإيموجي من القاموس المعتمد لديك
    final symbol = MarketingCard.iconSymbols[resolvedKey] ?? '⭐';

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
    // ignore: unused_local_variable
    final remainingDays = _getRemainingDays();

    final storeStatus = _getStoreStatus();

    final isExpired = storeStatus == 'منتهي';

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
                  color: isExpired ? Colors.red.shade50 : Colors.indigo.shade50,
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
                        color: isExpired ? Colors.red : const Color(0xFF28A9CC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusLabel(),
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
            //
            // المتجر يظل ظاهراً حتى بعد انتهاء الاشتراك.
            // لكن الطلب عبر واتساب يتوقف.
            // ==================================================
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isExpired
                      ? null
                      : () => _openWhatsApp(user.customWhatsApp ?? user.phone),
                  icon: Icon(
                    Icons.chat,
                    color: isExpired ? Colors.grey : Colors.green,
                    size: 18,
                  ),
                  label: Text(
                    isExpired
                        ? 'الطلب متوقف لانتهاء الاشتراك'
                        : 'واتساب المتجر',
                    style: TextStyle(
                      color: isExpired ? Colors.grey : Colors.green,
                      fontSize: 12,
                    ),
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
            // EXPIRED
            //
            // لا نخفي المتجر ولا المنتجات.
            // فقط نوضح أن الطلبات متوقفة.
            // ==================================================
            if (isExpired)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 15, 30, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        color: Colors.red,
                        size: 28,
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'انتهت مدة الاشتراك. المتجر ظاهر للزوار، '
                          'لكن استقبال الطلبات متوقف حالياً. '
                          'يمكن إعادة تفعيل الطلبات بعد التجديد.',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ==================================================
            // CARDS DISPLAY SECTION (WITH VERCEL API PROXY)
            // ==================================================
            if (publicCards.isEmpty) ...[
              // 🚀 حماية: عدم إرسال الطلب أبداً إذا كان الـ guardianMoxId فارغاً لمنع خطأ الـ Timeout
              if (guardianMoxId.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    '⚠️ رقم معرف المتجر غير متوفر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ] else ...[
                // 🚀 جلب بيانات المتجر مباشرة من الـ API الجديد على Vercel
                FutureBuilder<http.Response>(
                  future: http.get(
                    Uri.parse('/api/store').replace(
                      queryParameters: {'guardianMoxId': guardianMoxId},
                    ),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.statusCode != 200) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'لا توجد منتجات أو خدمات منشورة حالياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }

                    try {
                      // تفكيك الـ JSON القادم من الـ API
                      final dynamic decoded = jsonDecode(snapshot.data!.body);

                      // استخراج البطاقات بناءً على هيكلة الاستجابة
                      List<dynamic> rawCards = [];
                      if (decoded is Map<String, dynamic>) {
                        rawCards =
                            decoded['cards'] as List<dynamic>? ??
                            decoded['data'] as List<dynamic>? ??
                            [];
                      } else if (decoded is List) {
                        rawCards = decoded;
                      }

                      if (rawCards.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'لا توجد بطاقات متاحة لهذا المتجر حالياً.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      // عرض البطاقات بنفس التصميم السيادي
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rawCards.length,
                        itemBuilder: (context, index) {
                          final cardData = rawCards[index] is Map
                              ? rawCards[index]
                              : {};
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              title: Text(
                                cardData['title'] ?? cardData['name'] ?? '',
                              ),
                              subtitle: Text(cardData['description'] ?? ''),
                              trailing: Text('${cardData['price'] ?? ''}'),
                            ),
                          );
                        },
                      );
                    } catch (e) {
                      return Text('خطأ في معالجة بيانات المتجر: $e');
                    }
                  },
                ),
              ],
            ]
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
                                    backgroundColor: isExpired
                                        ? Colors.grey
                                        : Colors.green,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    minimumSize: const Size(
                                      double.infinity,
                                      38,
                                    ),
                                  ),
                                  onPressed: isExpired
                                      ? null
                                      : () => _openWhatsApp(whatsapp),
                                  icon: Icon(
                                    isExpired
                                        ? Icons.lock_outline
                                        : Icons.shopping_bag_outlined,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  label: Text(
                                    isExpired
                                        ? 'الطلب متوقف'
                                        : 'طلب عبر واتساب',
                                    style: const TextStyle(
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
