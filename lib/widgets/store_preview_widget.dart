import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../models/marketing_card.dart';

class StorePreviewWidget extends StatefulWidget {
  final UserModel user;

  // أبقيتها في الواجهة حتى لا تنكسر الاستدعاءات القديمة،
  // لكن مصدر الحقيقة للمتجر هو user.myAssets.
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

  @override
  State<StorePreviewWidget> createState() => _StorePreviewWidgetState();
}

class _StorePreviewWidgetState extends State<StorePreviewWidget> {
  // ============================================================
  // ⏱️ TIMER
  //
  // يعيد بناء الواجهة تلقائياً حتى لا يبقى عداد الأيام ثابتاً.
  // ============================================================

  Timer? _refreshTimer;

  // ============================================================
  // USER
  // ============================================================

  UserModel get user => widget.user;

  // ============================================================
  // 🆔 معرف المتجر
  // ============================================================

  String get guardianMoxId {
    return user.guardianMoxId?.trim() ?? '';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startRefreshTimer();
  }

  // ============================================================
  // TIMER
  //
  // نعيد بناء الواجهة كل ساعة كشبكة أمان.
  //
  // والحساب نفسه يعتمد على تاريخ اليوم، لذلك لا نعتمد على
  // قيمة محفوظة للعداد.
  // ============================================================

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {});
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    super.dispose();
  }

  // ============================================================
  // 📅 تاريخ نشر المتجر
  //
  // المصدر السيادي الثابت للاشتراك.
  // ============================================================

  DateTime? _getPublishDate() {
    final String value = user.storePublishDate?.trim() ?? '';

    if (value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }

    try {
      final DateTime parsed = DateTime.parse(value);

      // نستخدم اليوم فقط في حساب الاشتراك.
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // 📅 تاريخ اليوم
  //
  // بدون ساعات ودقائق وثواني.
  // ============================================================

  DateTime _today() {
    final DateTime now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  // ============================================================
  // ⏳ تاريخ انتهاء الاشتراك
  //
  // 365 يوماً من تاريخ النشر.
  // ============================================================

  DateTime? _getExpiryDate() {
    final DateTime? publishDate = _getPublishDate();

    if (publishDate == null) {
      return null;
    }

    return publishDate.add(const Duration(days: 365));
  }

  // ============================================================
  // 🔴 هل الاشتراك منتهي؟
  //
  // يعتمد فقط على تاريخ النشر.
  // ============================================================

  bool _isSubscriptionExpired() {
    final DateTime? expiryDate = _getExpiryDate();

    if (expiryDate == null) {
      return false;
    }

    final DateTime today = _today();

    return !today.isBefore(expiryDate);
  }

  // ============================================================
  // 📊 الأيام المتبقية
  //
  // مهم:
  //
  // لا نستخدم:
  //
  // expiryDate.difference(DateTime.now()).inDays
  //
  // لأن ذلك يحسب الساعات أيضاً.
  //
  // هنا نحسب الفرق بين يومين تقويميين فقط.
  // ============================================================

  int _getRemainingDays() {
    final DateTime? expiryDate = _getExpiryDate();

    if (expiryDate == null) {
      return 365;
    }

    final DateTime today = _today();

    final int difference = expiryDate.difference(today).inDays;

    if (difference <= 0) {
      return 0;
    }

    return difference;
  }

  // ============================================================
  // 🏪 حالة المتجر
  // ============================================================

  String _getStatusLabel() {
    if (_isSubscriptionExpired()) {
      return 'منتهي';
    }

    final int remainingDays = _getRemainingDays();

    if (remainingDays <= 0) {
      return 'منتهي';
    }

    return 'متبقي $remainingDays يوم';
  }

  // ============================================================
  // 📅 تنسيق التاريخ للعرض
  //
  // activationDate عرض فقط.
  // لا يدخل في أي شرط.
  // ============================================================

  String _formatDisplayDate(String? value) {
    final String date = value?.trim() ?? '';

    if (date.isEmpty || date.toLowerCase() == 'null') {
      return 'غير محدد';
    }

    try {
      final DateTime parsed = DateTime.parse(date);

      final String day = parsed.day.toString().padLeft(2, '0');

      final String month = parsed.month.toString().padLeft(2, '0');

      final String year = parsed.year.toString();

      return '$year-$month-$day';
    } catch (_) {
      return date;
    }
  }

  // ============================================================
  // 🛒 الأصول / البطاقات
  //
  // المصدر الحقيقي الوحيد = user.myAssets
  // ============================================================

  List<MarketingCard> _getPublicCards() {
    return user.myAssets
        .where((MarketingCard card) => card.isApproved)
        .toList();
  }

  // ============================================================
  // 📱 واتساب
  //
  // الاشتراك المنتهي يوقف الطلب فقط.
  // المتجر نفسه لا يختفي.
  // ============================================================

  Future<void> _openWhatsApp(String phone) async {
    if (_isSubscriptionExpired()) {
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanPhone.isEmpty) {
      cleanPhone = (user.customWhatsApp ?? '').replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleanPhone.isEmpty) {
      cleanPhone = user.phone.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleanPhone.isEmpty) {
      return;
    }

    final Uri url = Uri.parse('https://wa.me/$cleanPhone');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ============================================================
  // 📘 فيسبوك
  // ============================================================

  Future<void> _openFacebook(String urlString) async {
    final String value = urlString.trim();

    if (value.isEmpty) {
      return;
    }

    final Uri? url = Uri.tryParse(value);

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
  // 🛒 الأيقونات وقائمة الخيارات
  // ============================================================

  static const List<Map<String, dynamic>> _availableIcons = [
    {"name": "حقيبة تسوق", "icon": Icons.shopping_bag},
    {"name": "متجر", "icon": Icons.store},
    {"name": "توصيل", "icon": Icons.local_shipping},
    {"name": "هدية", "icon": Icons.card_giftcard},
    {"name": "نجمة", "icon": Icons.star},
    {"name": "بطاقة", "icon": Icons.credit_card},
    {"name": "عرض", "icon": Icons.local_offer},
    {"name": "خدمة عملاء", "icon": Icons.headset_mic},
  ];

  static IconData getIconData(String iconName) {
    final Map<String, dynamic> item = _availableIcons.firstWhere(
      (element) =>
          element['name'] == iconName ||
          element['icon'].toString().contains(iconName),
      orElse: () => {"icon": Icons.star},
    );

    return item['icon'];
  }

  // ============================================================
  // 🎨 أيقونة البطاقة
  // ============================================================

  Widget _buildCardIcon(MarketingCard card) {
    final String rawValue =
        (card.category.isNotEmpty ? card.category : card.iconKey).trim();

    String resolvedKey = 'نجمة';

    switch (rawValue) {
      case 'حقيبة تسوق':
      case 'shopping_bag':
        resolvedKey = 'حقيبة تسوق';
        break;

      case 'متجر':
      case 'متجر وتجارة':
      case 'store':
        resolvedKey = 'متجر';
        break;

      case 'توصيل':
      case 'local_shipping':
        resolvedKey = 'توصيل';
        break;

      case 'هدية':
      case 'card_giftcard':
        resolvedKey = 'هدية';
        break;

      case 'نجمة':
      case 'star':
        resolvedKey = 'نجمة';
        break;

      case 'بطاقة':
      case 'credit_card':
        resolvedKey = 'بطاقة';
        break;

      case 'عرض':
      case 'local_offer':
        resolvedKey = 'عرض';
        break;

      case 'خدمة عملاء':
      case 'headset_mic':
        resolvedKey = 'خدمة عملاء';
        break;

      default:
        resolvedKey = 'نجمة';
    }

    return Icon(
      getIconData(resolvedKey),
      color: const Color(0xFF1B6B80),
      size: 24,
    );
  }

  // ============================================================
  // 📦 بطاقة المنتج / الخدمة
  // ============================================================

  Widget _buildProductCard(
    BuildContext context,
    MarketingCard card,
    bool isExpired,
  ) {
    final String whatsapp = card.whatsapp.isNotEmpty
        ? card.whatsapp
        : (user.customWhatsApp ?? user.phone);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        card.title.isNotEmpty ? card.title : 'منتج أو خدمة',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1B6B80),
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (card.iconLabel.isNotEmpty)
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF28A9CC).withValues(alpha: 0.08),
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
                      backgroundColor: isExpired ? Colors.grey : Colors.green,
                      disabledBackgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(double.infinity, 38),
                    ),
                    onPressed: isExpired ? null : () => _openWhatsApp(whatsapp),
                    icon: Icon(
                      isExpired
                          ? Icons.lock_outline
                          : Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: Text(
                      isExpired ? 'الطلب متوقف' : 'طلب عبر واتساب',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),

                if (card.facebookUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),

                  IconButton(
                    tooltip: 'فيسبوك',
                    onPressed: () => _openFacebook(card.facebookUrl),
                    icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🏪 جسم المتجر الكامل
  // ============================================================

  Widget _buildStoreContent(
    BuildContext context,
    List<MarketingCard> publicCards,
  ) {
    final bool isExpired = _isSubscriptionExpired();

    // ignore: unused_local_variable
    final int remainingDays = _getRemainingDays();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ==================================================
            // 🏪 رأس المتجر
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
            // 📅 تاريخ التفعيل
            //
            // عرض فقط.
            // ==================================================
            if (user.activationDate != null &&
                user.activationDate!.trim().isNotEmpty &&
                user.activationDate!.toLowerCase() != 'null') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'تاريخ التفعيل:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                          fontSize: 12,
                        ),
                      ),

                      Text(
                        _formatDisplayDate(user.activationDate),
                        style: const TextStyle(
                          color: Color(0xFF1B6B80),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ==================================================
            // 🚦 حالة المتجر
            //
            // تعتمد فقط على storePublishDate.
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                width: double.infinity,
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
            // 📱 واتساب المتجر
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
            // 🛒 عنوان الأصول
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
            // 🔴 انتهاء الاشتراك
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
                          'انتهت مدة الاشتراك. '
                          'المتجر ظاهر للزوار، '
                          'لكن استقبال الطلبات '
                          'متوقف حالياً.',
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
            // 🛒 الأصول
            // ==================================================
            if (publicCards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'لا توجد منتجات أو خدمات منشورة حالياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: publicCards.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildProductCard(
                    context,
                    publicCards[index],
                    isExpired,
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
  // 🔒 المعاينة الخاصة
  // ============================================================

  Widget _buildPrivatePreview(BuildContext context) {
    final List<MarketingCard> cards = _getPublicCards();

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
    if (widget.isPublicView) {
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

    return _buildPrivatePreview(context);
  }
}
