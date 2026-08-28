// ignore_for_file: unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../services/storage_service.dart';
import '../screens/digital_signature_screen.dart';
import '../widgets/store_preview_widget.dart';
import '../helpers/store_url_helper.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;

  // نحافظ عليهما حتى لا تنكسر الاستدعاءات القديمة.
  final String? directMoxId;
  final List<Map<String, dynamic>> clientCards;

  // true = العرض العام
  // false = لوحة الإدارة
  final bool isPublic;

  const ClientStoreAdminScreen({
    super.key,
    required this.user,
    this.directMoxId,
    this.clientCards = const [],
    this.isPublic = false,
  });

  @override
  State<ClientStoreAdminScreen> createState() => _ClientStoreAdminScreenState();
}

class _ClientStoreAdminScreenState extends State<ClientStoreAdminScreen> {
  // ============================================================
  // 🔐 إعدادات التنشيط المرتبطة برابط قوقل
  // ============================================================

  static const String _googleStoreApiUrl =
      "https://script.google.com/macros/s/AKfycbxr1Fiq7D1Tfapos19WGXr_Hnqj34qnz4i3K73A-fbjXRYIbcE0mKNn6nIM-c8uwfzSsg/exec";

  static const int _subscriptionDays = 365;

  // مفتاح توافقية مؤقت لكي لا تتأثر شاشة التحقق ويقبل الكود الإدخال
  static const String _sovereignActivationKey = "MOX-2026-KEY-9876543210AB";

  // ============================================================
  // 🎨 هوية MOX
  // ============================================================

  static const Color _primaryColor = Color(0xFF28A9CC);

  static const Color _darkColor = Color(0xFF1B6B80);

  static const Color _indigoColor = Color(0xFF303F9F);

  // ============================================================
  // 📝 Form
  // ============================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _storeNameController = TextEditingController();

  final TextEditingController _businessCategoryController =
      TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _linkController = TextEditingController();

  // ============================================================
  // 🛒 الأيقونات
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

  // ignore: unused_element
  static IconData getIconData(String iconName) {
    final item = _availableIcons.firstWhere(
      (element) => element['name'] == iconName,
      orElse: () => {"icon": Icons.star},
    );
    return item['icon'];
  }

  // ============================================================
  // 🧱 البطاقات الخمس الأساسية
  // ============================================================

  final List<Map<String, dynamic>> _resolvedCards = [
    {
      "title": "البطاقة السيادية الأولى للمتجر",
      "description":
          "الوصف الهندسي للبطاقة الأولى ويغطي كافة تفاصيل العرض الأساسي.",
      "price": 1000.0,
      "category": "بطاقة",
    },
    {
      "title": "البطاقة السيادية الثانية للمتجر",
      "description":
          "الوصف الهندسي للبطاقة الثانية ويغطي كافة تفاصيل العرض الفرعي.",
      "price": 2000.0,
      "category": "بطاقة",
    },
    {
      "title": "القسم السيادي الثالث للمتجر",
      "description":
          "الوصف الهندسي للقسم الثالث ويغطي تصنيفات المنتجات والخدمات.",
      "price": 3000.0,
      "category": "قسم",
    },
    {
      "title": "الرف السيادي الرابع للمتجر",
      "description": "الوصف الهندسي للرف الرابع ويغطي عرض المنتجات المميزة.",
      "price": 4000.0,
      "category": "رف",
    },
    {
      "title": "البطاقة السيادية الخامسة للمتجر",
      "description": "الوصف الهندسي للبطاقة الخامسة وتختتم حزمة الأصول.",
      "price": 5000.0,
      "category": "بطاقة",
    },
  ];

  // ============================================================
  // ⚙️ حالة البطاقات والتحكم
  // ============================================================

  final Map<String, bool> _cardActivationStatus = {};
  final Map<String, String> _cardCategories = {};
  final Map<String, IconData> _cardSelectedIcons = {};

  final Map<String, TextEditingController> _cardTitleControllers = {};
  final Map<String, TextEditingController> _cardDescControllers = {};
  final Map<String, TextEditingController> _cardPriceControllers = {};
  final Map<String, TextEditingController> _cardWhatsappControllers = {};
  final Map<String, TextEditingController> _cardDetailsLinkControllers = {};

  // ============================================================
  // 🔐 الحالة ومتغيرات المتجر العام الجديد
  // ============================================================

  bool _isAuthorized = false;
  bool _isPublishing = false;
  bool _isSubscriptionExpired = false;

  int _activationButtonState = 0;

  bool _storeLoading = false;
  String? _publicGuardianMoxId;
  UserModel? _publicUser;
  bool _publicLoadFinished = false;

  late UserModel _liveUser;

  // ============================================================
  // 🚀 INIT & التهيئة الذكية (مصحح ومحصن)
  // ============================================================

  @override
  void initState() {
    super.initState();

    // الخطأ 1: ضمان تحديث الكائن الحي فوراً لمنع التفرغ
    _liveUser = widget.user;

    // الخطأ 2: تأمين جلب المعرف السيادي بدقة متناهية ودون انقطاع
    _publicGuardianMoxId =
        widget.directMoxId?.trim().toUpperCase() ??
        StoreUrlHelper.extractGuardianMoxId()?.trim().toUpperCase() ??
        widget.user.guardianMoxId?.trim().toUpperCase();

    // الخطأ 3: إطلاق بوابة التهيئة المتكاملة
    _initializeStore();
  }

  // ============================================================
  // 🧠 بوابة التهيئة الرئيسية
  // ============================================================

  Future<void> _initializeStore() async {
    if (widget.isPublic) {
      await _loadPublicStore();
    } else {
      await _loadPrivateStore();
    }
  }

  // ============================================================
  // 🔄 حراسة دورة الحياة لتحديث الحقول بعد الخروج والعودة
  // ============================================================
  @override
  void didUpdateWidget(covariant ClientStoreAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.user != oldWidget.user ||
        widget.isPublic != oldWidget.isPublic ||
        widget.directMoxId != oldWidget.directMoxId) {
      _liveUser = widget.user;
      _publicGuardianMoxId =
          widget.directMoxId?.trim().toUpperCase() ??
          StoreUrlHelper.extractGuardianMoxId()?.trim().toUpperCase() ??
          widget.user.guardianMoxId?.trim().toUpperCase();
      _initializeStore();
    }
  }
  // ============================================================
  // 🌐 تحميل المتجر العام
  // المتجر هنا كائن واحد كامل
  // ============================================================

  Future<void> _loadPublicStore() async {
    if (_publicLoadFinished) return;

    final String guardianId = (_publicGuardianMoxId ?? '').trim().toUpperCase();

    if (guardianId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _publicUser = null;
        _publicLoadFinished = true;
        _storeLoading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _storeLoading = true;
      });
    }

    try {
      final UserModel? user = await StorageService.getByGuardianMoxId(
        guardianId,
      );

      if (!mounted) return;

      if (user == null) {
        debugPrint('❌ [STORE PUBLIC] لم يتم العثور على المتجر: $guardianId');

        setState(() {
          _publicUser = null;
          _publicLoadFinished = true;
          _storeLoading = false;
        });

        return;
      }

      debugPrint('✅ [STORE PUBLIC] تم تحميل كائن المتجر كاملاً: ${user.name}');

      // ==========================================================
      // 🏪 المتجر = UserModel واحد كامل
      // ==========================================================

      setState(() {
        _publicUser = user;
        _liveUser = user;
        _publicLoadFinished = true;
        _storeLoading = false;
      });

      // ==========================================================
      // التهيئة الخاصة بالعرض
      // ==========================================================

      _initializeControllers();

      // ==========================================================
      // الاشتراك يعتمد على storePublishDate فقط
      // ==========================================================

      _initializeSubscription();

      debugPrint('🏪 STORE: ${user.name}');

      debugPrint('🆔 GUARDIAN: ${user.guardianMoxId}');

      debugPrint('📅 ACTIVATION: ${user.activationDate}');

      debugPrint('🚀 PUBLISH: ${user.storePublishDate}');

      debugPrint('🛒 ASSETS: ${user.myAssets.length}');
    } catch (e) {
      debugPrint('❌ [STORE PUBLIC] $e');

      if (!mounted) return;

      setState(() {
        _publicUser = null;
        _publicLoadFinished = true;
        _storeLoading = false;
      });
    }
  }
  // ============================================================
  // 🔒 تحميل المتجر الخاص — لوحة الإدارة
  // ============================================================

  Future<void> _loadPrivateStore() async {
    if (mounted) {
      setState(() {
        _storeLoading = true;
      });
    }

    try {
      final UserModel? storedUser = await StorageService.getUser();

      if (!mounted) return;

      if (storedUser != null) {
        // ✨ النسخ المباشر والآمن: جعل activationDate ينسخ storePublishDate تلقائياً وبدون شروط
        final String pubDate = storedUser.storePublishDate ?? '';
        _liveUser = storedUser.copyWith(
          activationDate: pubDate.isNotEmpty && pubDate != 'null'
              ? pubDate
              : storedUser.activationDate,
        );
      }

      // ==========================================================
      // تهيئة المتجر بالكامل من نفس الكائن المحدث
      // ==========================================================

      _initializeControllers();

      _initializeCards();

      _initializeSubscription();

      _updateStoreLink();
    } catch (e, stackTrace) {
      debugPrint('❌ [STORE PRIVATE] $e');
      debugPrint('$stackTrace');
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;

      setState(() {
        _storeLoading = false;
      });
    }

    // ==========================================================
    // 🔐 فتح حماية الإدارة بعد اكتمال التهيئة
    // ==========================================================

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _showSecurityLoginDialog();
    });
  }
  // ============================================================
  // 📝 تهيئة المتحكمات
  // ============================================================

  void _initializeControllers() {
    _phoneController.text = _liveUser.phone;
    _storeNameController.text = _liveUser.name;
    _businessCategoryController.text = _liveUser.address;
    _descriptionController.text = _liveUser.storeDescription;

    if (_descriptionController.text.trim().isEmpty &&
        _liveUser.myAssets.isNotEmpty) {
      _descriptionController.text = _liveUser.myAssets.first.description;
    }
  }

  // ============================================================
  // 🛒 توحيد تحميل البطاقات والأصول
  // ============================================================

  void _initializeCards() {
    // تنظيف الحالة القديمة
    _cardActivationStatus.clear();
    _cardCategories.clear();
    _cardSelectedIcons.clear();

    for (final controller in _cardTitleControllers.values) {
      controller.dispose();
    }

    for (final controller in _cardDescControllers.values) {
      controller.dispose();
    }

    for (final controller in _cardPriceControllers.values) {
      controller.dispose();
    }

    for (final controller in _cardWhatsappControllers.values) {
      controller.dispose();
    }

    for (final controller in _cardDetailsLinkControllers.values) {
      controller.dispose();
    }

    _cardTitleControllers.clear();
    _cardDescControllers.clear();
    _cardPriceControllers.clear();
    _cardWhatsappControllers.clear();
    _cardDetailsLinkControllers.clear();

    // ==========================================================
    // 📦 الأصول الحقيقية القادمة مع UserModel
    // ==========================================================

    final List<MarketingCard> assets = List<MarketingCard>.from(
      _liveUser.myAssets,
    );

    // ==========================================================
    // 🧠 خريطة الأصول حسب العنوان
    // ==========================================================

    final Map<String, MarketingCard> assetsByTitle = {};

    for (final MarketingCard asset in assets) {
      final String key = asset.title.trim();

      if (key.isEmpty) continue;

      assetsByTitle[key.toUpperCase()] = asset;
    }

    // ==========================================================
    // 🛒 بناء البطاقات من نفس المصدر
    // ==========================================================

    for (final cardData in _resolvedCards) {
      final String titleKey = cardData['title'].toString().trim();

      final MarketingCard? existingAsset =
          assetsByTitle[titleKey.toUpperCase()];

      final bool isActive = existingAsset != null;

      _cardActivationStatus[titleKey] = isActive;

      _cardCategories[titleKey] =
          existingAsset?.category ??
          cardData['category']?.toString() ??
          'بطاقة';

      _cardSelectedIcons[titleKey] = Icons.shopping_bag;

      _cardTitleControllers[titleKey] = TextEditingController(
        text: existingAsset?.title ?? titleKey,
      );

      _cardDescControllers[titleKey] = TextEditingController(
        text:
            existingAsset?.description ??
            cardData['description']?.toString() ??
            '',
      );

      _cardPriceControllers[titleKey] = TextEditingController(
        text: (existingAsset?.price ?? cardData['price'] ?? 0.0).toString(),
      );

      _cardWhatsappControllers[titleKey] = TextEditingController(
        text: existingAsset?.whatsapp.isNotEmpty == true
            ? existingAsset!.whatsapp
            : (_liveUser.customWhatsApp ?? _liveUser.phone),
      );

      _cardDetailsLinkControllers[titleKey] = TextEditingController(
        text: existingAsset?.facebookUrl ?? '',
      );
    }

    debugPrint('📦 [CARDS INIT] تم توحيد ${assets.length} أصل مع البطاقات.');
  }

  // ============================================================
  // ⏳ الاشتراك وإدارته
  // ============================================================

  void _initializeSubscription() async {
    // 🎯 الخطوة الأولى: محاولة استرجاع التاريخ المخزن محلياً أولاً لضمان عدم ضياعه عند الخروج
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? localPubDate = prefs.getString(
        'store_pub_date_$_publicGuardianMoxId',
      );
      if (localPubDate != null &&
          localPubDate.trim().isNotEmpty &&
          localPubDate != "null") {
        if (_liveUser.storePublishDate == null ||
            _liveUser.storePublishDate!.trim().isEmpty ||
            _liveUser.storePublishDate == "null") {
          _liveUser = _liveUser.copyWith(
            storePublishDate: localPubDate,
            activationDate: localPubDate,
            role: 'reviewed_active',
          );
        }
      }
    } catch (_) {}

    final String? publishDate = _liveUser.storePublishDate;
    if (publishDate == null ||
        publishDate.trim().isEmpty ||
        publishDate == "null") {
      _isSubscriptionExpired = false;
      _activationButtonState = 0;
      return;
    }

    _isSubscriptionExpired = _checkIf365DaysExpired(publishDate);
    _activationButtonState = _isSubscriptionExpired ? 0 : 1;
  }

  bool _checkIf365DaysExpired(String? publishDateStr) {
    if (publishDateStr == null ||
        publishDateStr.trim().isEmpty ||
        publishDateStr == "null") {
      return false;
    }
    try {
      final DateTime publishDate = DateTime.parse(publishDateStr);
      final DateTime expiryDate = publishDate.add(
        const Duration(days: _subscriptionDays),
      );
      return DateTime.now().isAfter(expiryDate);
    } catch (_) {
      return false;
    }
  }

  int _getRemainingDays() {
    final String? date = _liveUser.storePublishDate;
    if (date == null || date.trim().isEmpty || date == "null") {
      return _subscriptionDays;
    }
    try {
      final DateTime publishDate = DateTime.parse(date);
      final DateTime expiryDate = publishDate.add(
        const Duration(days: _subscriptionDays),
      );

      // 🎯 الحل: توحيد التاريخ بتجاهل الساعات والدقائق والثواني نهائياً
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime expiryDay = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );

      final int days = expiryDay.difference(today).inDays;

      if (days < 0) return 0;
      return days;
    } catch (_) {
      return _subscriptionDays;
    }
  }

  // ============================================================
  // 🔄 مزامنة حالة الاشتراك بناءً على التاريخ السيادي
  // ============================================================

  void _syncSubscriptionState() {
    final String pubDate = _liveUser.storePublishDate?.trim() ?? '';

    // فحص هل التاريخ موجود وصحيح ولم تنتهِ الـ 365 يوماً؟
    final bool hasValidDate = pubDate.isNotEmpty && pubDate != "null";
    final bool isExpired = hasValidDate
        ? _checkIf365DaysExpired(pubDate)
        : true;

    setState(() {
      _isSubscriptionExpired = isExpired;
      // إذا كان هناك تاريخ صالح ولم ينتهِ الاشتراك، اجعل الحالة 1 فوراً (متجر مفعل)
      // وإذا لم يكن هناك تاريخ أو انتهى، اجعلها 0 (زر بدء التشغيل)
      _activationButtonState = (!isExpired && hasValidDate) ? 1 : 0;
    });
  }

  // ============================================================
  // ⏳ الاشتراك وإدارته (محدث لضمان استمرار ظهور زر النشر طوال العام وحفظ الجلسة)
  // ============================================================

  Future<void> _startSubscription() async {
    final String? existingDate = _liveUser.storePublishDate;
    if (existingDate != null &&
        existingDate.trim().isNotEmpty &&
        existingDate != "null") {
      // حتى لو كان موجوداً مسبقاً، نقوم بمزامنة الحالة لضمان عدم تراجع الزر
      _syncSubscriptionState();
      return;
    }

    final String startDate = DateTime.now().toIso8601String();
    final UserModel activatedUser = _liveUser.copyWith(
      storePublishDate: startDate,
      activationDate: startDate, // تثبيت تاريخ التفعيل لضمان عدم فقدانه في قوقل
      role: 'reviewed_active',
    );

    try {
      await StorageService.updateUserPartial(activatedUser);
      _liveUser = activatedUser;

      // 🎯 حفظ التاريخ محلياً لضمان بقاء الجلسة ثابتة حتى بعد الخروج والتسجيل
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'store_pub_date_$_publicGuardianMoxId',
          startDate,
        );
      } catch (_) {}

      if (!mounted) return;

      // استدعاء دالة المزامنة الموحدة لتحديث الواجهة وزر النشر بثبات تام
      _syncSubscriptionState();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 تم تشغيل المتجر بنجاح — بدأت مدة الـ365 يوماً."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ حدث خطأ أثناء بدء الاشتراك: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ============================================================
  // 🔗 رابط المتجر العام
  // ============================================================

  void _updateStoreLink() {
    final String guardianMox =
        (widget.user.guardianMoxId ?? _publicGuardianMoxId ?? '').trim();
    if (guardianMox.isEmpty ||
        guardianMox == 'null' ||
        guardianMox == 'لم يحدد') {
      _linkController.text = '';
      return;
    }
    _linkController.text = 'https://mox-2026.vercel.app/store/$guardianMox';
  }

  // ============================================================
  // 🔐 الأمان وتسجيل الدخول المحلي
  // ============================================================

  Future<UserModel?> _findUserFromGoogle(String enteredMox) async {
    final String normalized = enteredMox.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      return await StorageService.getUserByMoxId(normalized);
    } catch (e) {
      return null;
    }
  }

  Future<void> _showSecurityLoginDialog() async {
    final TextEditingController securityController = TextEditingController();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.security, color: _primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "تأكيد هوية المالك",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "أدخل رقم موكس الخاص بك لتأكيد صلاحية الوصول.",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: securityController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "رقم MOX",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () async {
                final String entered = securityController.text
                    .trim()
                    .toUpperCase();
                final String localMox = _liveUser.moxId.trim().toUpperCase();
                final String guardianMox = (_liveUser.guardianMoxId ?? '')
                    .trim()
                    .toUpperCase();

                Navigator.pop(ctx);

                final bool matched =
                    entered.isNotEmpty &&
                    (entered == localMox || entered == guardianMox);
                if (matched) {
                  setState(() => _isAuthorized = true);
                  return;
                }

                final UserModel? remoteUser = await _findUserFromGoogle(
                  entered,
                );
                if (remoteUser != null &&
                    (remoteUser.moxId.trim().toUpperCase() == localMox ||
                        (remoteUser.guardianMoxId ?? '').trim().toUpperCase() ==
                            guardianMox)) {
                  setState(() => _isAuthorized = true);
                  return;
                }

                _showLuxuryErrorDialog();
              },
              child: const Text(
                "تأكيد",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    securityController.dispose();
  }

  // ============================================================
  // 🔐 الفحص والنشر الفعلي
  // ============================================================

  Future<void> _showStoreValidationDialog(
    List<MarketingCard> updatedAssets,
  ) async {
    final TextEditingController moxController = TextEditingController();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: _primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "فحص هوية المتجر",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "أدخل رقم موكس الخاص بك للتأكد من ربطه بملفك ونشر المتجر.",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: moxController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "رقم MOX",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () async {
                final String enteredMox = moxController.text
                    .trim()
                    .toUpperCase();
                final String userMox = _liveUser.moxId.trim().toUpperCase();
                final String guardianMox = (_liveUser.guardianMoxId ?? '')
                    .trim()
                    .toUpperCase();

                final bool moxMatched =
                    enteredMox.isNotEmpty &&
                    (enteredMox == userMox || enteredMox == guardianMox);
                Navigator.pop(ctx);

                if (!moxMatched) {
                  _showLuxuryErrorDialog();
                  return;
                }

                await _executeStorePublish(updatedAssets);
              },
              child: const Text(
                "فحص ونشر",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    moxController.dispose();
  }

  Future<void> _executeStorePublish(List<MarketingCard> updatedAssets) async {
    if (!mounted) return;

    setState(() {
      _isPublishing = true;
    });

    try {
      // ============================================================
      // 📅 تحديد تاريخ النشر الحالي
      // ============================================================

      final String existingPublishDate = (_liveUser.storePublishDate ?? '')
          .trim();

      // التحقق هل يوجد تاريخ نشر سابق وما زال صالحًا
      final bool hasValidExistingPublishDate =
          existingPublishDate.isNotEmpty &&
          existingPublishDate.toLowerCase() != 'null' &&
          !_checkIf365DaysExpired(existingPublishDate);

      // ============================================================
      // 🕐 تاريخ النشر الجديد
      // ============================================================
      //
      // نستخدم تاريخ اليوم فقط:
      //
      // 2026-08-27
      //
      // بدل:
      //
      // 2026-08-27T18:42:31.123456
      //
      // لأن النظام عندك يتعامل مع تاريخ الاشتراك بالأيام.
      // ============================================================

      final String finalPublishDate = hasValidExistingPublishDate
          ? existingPublishDate
          : DateTime.now().toIso8601String().split('T').first;

      debugPrint(
        '============================================================',
      );
      debugPrint('🏪 [STORE PUBLISH] بدء عملية نشر المتجر');
      debugPrint('📅 [STORE PUBLISH] التاريخ السابق: $existingPublishDate');
      debugPrint('📅 [STORE PUBLISH] التاريخ النهائي: $finalPublishDate');
      debugPrint(
        '============================================================',
      );

      // ============================================================
      // 👤 إنشاء نسخة المستخدم الجديدة
      // ============================================================

      final UserModel updatedUser = _liveUser.copyWith(
        name: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _businessCategoryController.text.trim(),
        storeDescription: _descriptionController.text.trim(),

        // الاحتفاظ بالأصول القديمة إذا لم توجد أصول جديدة
        myAssets: updatedAssets.isNotEmpty ? updatedAssets : _liveUser.myAssets,

        // ==========================================================
        // 📅 تاريخ النشر
        // ==========================================================
        storePublishDate: finalPublishDate,

        // ==========================================================
        // 📅 تاريخ التفعيل
        // ==========================================================
        activationDate: finalPublishDate,

        // ==========================================================
        // 🔓 تفعيل المتجر
        // ==========================================================
        role: 'reviewed_active',
      );

      // ============================================================
      // 🔎 تأكيد داخلي قبل الإرسال
      // ============================================================

      debugPrint('📤 [STORE PUBLISH] البيانات التي سيتم إرسالها:');

      debugPrint('   moxId = ${updatedUser.moxId}');

      debugPrint('   role = ${updatedUser.role}');

      debugPrint('   storePublishDate = ${updatedUser.storePublishDate}');

      debugPrint('   activationDate = ${updatedUser.activationDate}');

      // ============================================================
      // ☁️ الحفظ الفعلي في Google Sheets
      // ============================================================

      await StorageService.updateUserPartial(updatedUser);

      debugPrint('✅ [STORE PUBLISH] تم إرسال بيانات المتجر إلى Google Sheets');

      // ============================================================
      // 🔄 إعادة القراءة من Google
      // ============================================================
      //
      // هذه الخطوة مهمة جدًا:
      // لا نفترض أن الحفظ نجح.
      // نقرأ السجل مرة أخرى ونتأكد أن Google أعاد التاريخ.
      // ============================================================

      final UserModel? confirmedUser = await StorageService.getUserByMoxId(
        updatedUser.moxId,
      );

      // ============================================================
      // 🛡️ التأكد من وجود البيانات المسترجعة
      // ============================================================

      if (confirmedUser == null) {
        throw Exception(
          'تم إرسال البيانات ولكن تعذر إعادة قراءة بيانات المتجر من Google.',
        );
      }

      debugPrint(
        '============================================================',
      );
      debugPrint('🔄 [STORE PUBLISH] البيانات المؤكدة من Google:');
      debugPrint('   moxId = ${confirmedUser.moxId}');
      debugPrint('   role = ${confirmedUser.role}');
      debugPrint('   storePublishDate = ${confirmedUser.storePublishDate}');
      debugPrint('   activationDate = ${confirmedUser.activationDate}');
      debugPrint(
        '============================================================',
      );

      // ============================================================
      // 🚨 تحقق صريح من تاريخ النشر
      // ============================================================

      final String confirmedPublishDate = (confirmedUser.storePublishDate ?? '')
          .trim();

      if (confirmedPublishDate.isEmpty ||
          confirmedPublishDate.toLowerCase() == 'null') {
        throw Exception('تم حفظ المتجر ولكن Google لم يُرجع storePublishDate.');
      }

      // ============================================================
      // 🚨 تحقق صريح من تاريخ التفعيل
      // ============================================================

      final String confirmedActivationDate =
          (confirmedUser.activationDate ?? '').trim();

      if (confirmedActivationDate.isEmpty ||
          confirmedActivationDate.toLowerCase() == 'null') {
        throw Exception('تم حفظ المتجر ولكن Google لم يُرجع activationDate.');
      }

      // ============================================================
      // 💾 اعتماد البيانات المؤكدة
      // ============================================================

      _liveUser = confirmedUser;

      // ============================================================
      // 💾 نسخة احتياطية محلية
      // ============================================================

      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        final String storageKey =
            'store_pub_date_${_liveUser.guardianMoxId ?? _liveUser.moxId}';

        await prefs.setString(storageKey, confirmedPublishDate);

        debugPrint(
          '💾 [STORE PUBLISH] تم حفظ نسخة محلية من التاريخ: '
          '$confirmedPublishDate',
        );
      } catch (e) {
        debugPrint('⚠️ [STORE PUBLISH] تعذر حفظ النسخة المحلية: $e');
      }

      // ============================================================
      // 🎯 تحديث حالة الواجهة
      // ============================================================

      if (!mounted) return;

      setState(() {
        _isPublishing = false;

        _isSubscriptionExpired = _checkIf365DaysExpired(
          _liveUser.storePublishDate,
        );

        _activationButtonState = _isSubscriptionExpired ? 0 : 1;

        _isAuthorized = true;
      });

      // ============================================================
      // 🔗 تحديث رابط المتجر
      // ============================================================

      _updateStoreLink();

      // ============================================================
      // ✅ رسالة النجاح
      // ============================================================

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚀 تم نشر المتجر بنجاح\n'
            '📅 تاريخ النشر: $confirmedPublishDate\n'
            '📅 تاريخ التفعيل: $confirmedActivationDate',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '============================================================',
      );
      debugPrint('❌ [STORE PUBLISH] فشل نشر المتجر');
      debugPrint('❌ الخطأ: $e');
      debugPrint('📚 StackTrace: $stackTrace');
      debugPrint(
        '============================================================',
      );

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ حدث خطأ أثناء نشر المتجر:\n$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _showLuxuryErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "فشل الفحص",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "رقم موكس غير مطابق لبيانات هذا المتجر المحلي.",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text("حسناً", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  // ============================================================
  // 🔑 التنشيط والتجديد
  // ============================================================

  void _showActivationKeyDialog() {
    final TextEditingController keyController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_clock, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "انتهت صلاحية المتجر",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "انتهت مدة الاشتراك البالغة 365 يوماً.",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: keyController,
                maxLength: 40,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "مفتاح التنشيط",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                  isDense: true,
                  counterText: "",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              onPressed: () async {
                final String enteredKey = keyController.text
                    .trim()
                    .toUpperCase();
                if (enteredKey != _sovereignActivationKey.toUpperCase()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ مفتاح التنشيط غير صحيح."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _renewSubscription();
              },
              child: const Text(
                "تفعيل المتجر",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    keyController.dispose();
  }

  Future<void> _renewSubscription() async {
    final String newDate = DateTime.now().toIso8601String();
    final UserModel renewedUser = _liveUser.copyWith(
      storePublishDate: newDate,
      role: 'reviewed_active',
    );

    try {
      await StorageService.updateUserPartial(renewedUser);
      _liveUser = renewedUser;

      if (!mounted) return;
      setState(() {
        _isSubscriptionExpired = false;
        _activationButtonState = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ تم تجديد المتجر لمدة 365 يوماً جديدة."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ حدث خطأ أثناء حفظ التفعيل: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 🎨 اختيار الأيقونة (النسخة المحسنة والمضمونة)
  // ============================================================

  void _showIconSelectorDialog(String titleKey) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "اختر أيقونة البطاقة",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          content: SizedBox(
            width: 320,
            // استخدام SingleChildScrollView مع GridView لمنع أي مشاكل في المساحة أو الاختفاء
            child: SingleChildScrollView(
              child: GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(), // الاعتماد على التمرير الخارجي للنافذة
                itemCount: _availableIcons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio:
                      0.9, // ضبط نسبة العرض إلى الارتفاع لضمان عدم حدوث تداخل
                ),
                itemBuilder: (context, index) {
                  final item = _availableIcons[index];
                  final IconData icon = item['icon'];
                  final String name = item['name'];

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _cardSelectedIcons[titleKey] = icon);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: _darkColor, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
  // ============================================================
  // 🧱 بناء الأصول الحالية من واجهة المستخدم
  // ============================================================

  List<MarketingCard> _getCurrentAssetsFromUI() {
    final List<MarketingCard> assets = [];
    for (final cardData in _resolvedCards) {
      final String titleKey = cardData['title'].toString();
      final bool isActive = _cardActivationStatus[titleKey] ?? false;
      if (!isActive) continue;

      final String title =
          _cardTitleControllers[titleKey]?.text.trim() ?? titleKey;
      final String description =
          _cardDescControllers[titleKey]?.text.trim() ?? '';
      final double price =
          double.tryParse(
            _cardPriceControllers[titleKey]?.text.trim() ?? '0',
          ) ??
          0.0;
      final String whatsapp =
          _cardWhatsappControllers[titleKey]?.text.trim() ??
          _phoneController.text.trim();
      final String facebookUrl =
          _cardDetailsLinkControllers[titleKey]?.text.trim() ?? '';
      final String category = _cardCategories[titleKey] ?? 'بطاقة';

      assets.add(
        MarketingCard(
          title: title.isEmpty ? 'منتج أو خدمة' : title,
          description: description,
          price: price,
          whatsapp: whatsapp,
          facebookUrl: facebookUrl,
          category: category,
          isApproved: true,
        ),
      );
    }
    return assets;
  }

  UserModel _buildLiveUserModel() {
    return _liveUser.copyWith(
      name: _storeNameController.text.trim(),
      address: _businessCategoryController.text.trim(),
      phone: _phoneController.text.trim(),
      storeDescription: _descriptionController.text.trim(),
      myAssets: _getCurrentAssetsFromUI(),
    );
  }

  void _openStorePreview() {
    if (_isSubscriptionExpired) {
      _showActivationKeyDialog();
      return;
    }
    final UserModel liveUser = _buildLiveUserModel();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StorePreviewWidget(
          user: liveUser,
          allCards: _resolvedCards,
          activeStatus: _cardActivationStatus,
        );
      },
    );
  }

  Future<void> _publishStore() async {
    final bool hasSubscription =
        _liveUser.storePublishDate != null &&
        _liveUser.storePublishDate!.trim().isNotEmpty &&
        _liveUser.storePublishDate != "null";

    if (!hasSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 اضغط «بدء تشغيل المتجر — 365 يوماً» أولاً."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isSubscriptionExpired) {
      _showActivationKeyDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final List<MarketingCard> updatedAssets = _getCurrentAssetsFromUI();
    if (updatedAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ يجب تفعيل بطاقة واحدة على الأقل."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _showStoreValidationDialog(updatedAssets);
  }

  void _copyStoreLink() {
    Clipboard.setData(ClipboardData(text: _linkController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 تم نسخ رابط المتجر."),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // 🧹 DISPOSE
  // ============================================================

  @override
  void dispose() {
    _storeNameController.dispose();
    _businessCategoryController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();

    for (final controller in _cardTitleControllers.values) {
      controller.dispose();
    }
    for (final controller in _cardDescControllers.values) {
      controller.dispose();
    }
    for (final controller in _cardPriceControllers.values) {
      controller.dispose();
    }
    for (final controller in _cardWhatsappControllers.values) {
      controller.dispose();
    }
    for (final controller in _cardDetailsLinkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // 🧩 تصميم البطاقات (UI)
  // ============================================================

  Widget _buildMarketingCard(Map<String, dynamic> cardData) {
    final String titleKey = cardData['title'].toString();
    final bool isChecked = _cardActivationStatus[titleKey] ?? false;
    final String category = _cardCategories[titleKey] ?? 'بطاقة';
    final IconData selectedIcon =
        _cardSelectedIcons[titleKey] ?? Icons.shopping_bag;
    final bool canEditCards = _isAuthorized;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isChecked ? _primaryColor : Colors.grey.shade300,
          width: isChecked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: category,
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _darkColor,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'بطاقة', child: Text('بطاقة')),
                      DropdownMenuItem(value: 'قسم', child: Text('قسم')),
                      DropdownMenuItem(value: 'رف', child: Text('رف')),
                    ],
                    onChanged: canEditCards
                        ? (value) {
                            if (value == null) return;
                            setState(() => _cardCategories[titleKey] = value);
                          }
                        : null,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      "تنشيط",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Checkbox(
                      value: isChecked,
                      activeColor: _primaryColor,
                      onChanged: canEditCards
                          ? (value) => setState(
                              () => _cardActivationStatus[titleKey] =
                                  value ?? false,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: canEditCards
                      ? () => _showIconSelectorDialog(titleKey)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(selectedIcon, color: _darkColor, size: 31),
                        const SizedBox(height: 2),
                        const Text(
                          "أيقونة",
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: _darkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cardTitleControllers[titleKey],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: "عنوان المنتج / الخدمة",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _cardDescControllers[titleKey],
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: "الوصف",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardPriceControllers[titleKey],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "السعر",
                      suffixText: "ج.س",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _cardWhatsappControllers[titleKey],
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "واتساب",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              "اكتب رقم واتساب بالصيغة الدولية بدون +",
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardDetailsLinkControllers[titleKey],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "رابط التفاصيل / فيسبوك / فيديو",
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text(
          "المتجر مغلق",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_person_rounded,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                "انتهت مدة المتجر البالغة 365 يوماً.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _indigoColor,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "قم بإدخال مفتاح التنشيط لإعادة تشغيل المتجر.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: _isPublishing
                    ? null
                    : _publishStore, // متاح دائماً طوال العام للتعديل والحفظ دون قيود
                icon: _isPublishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, color: Colors.white),
                label: Text(
                  _isPublishing
                      ? "جاري الحفظ والنشر..."
                      : "💾 حفظ وتحديث ونشر المتجر", // يظل ظاهراً ونشطاً طوال الـ 365 يوماً
                  style: const TextStyle(
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
    );
  }

  // ============================================================
  // 🌐 BUILD الأساسي
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------
    // 1. عرض المتجر العام عبر Vercel
    // ----------------------------------------------------------
    if (widget.isPublic) {
      if (_storeLoading || !_publicLoadFinished) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (_publicUser == null) {
        return const Scaffold(body: Center(child: Text('المتجر غير موجود')));
      }

      return StorePreviewWidget(
        user: _publicUser!,
        allCards: _resolvedCards,
        activeStatus: _cardActivationStatus,
        isPublicView: true,
      );
    }

    // ----------------------------------------------------------
    // 2. منطقة الإدارة المحمية
    // ----------------------------------------------------------
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text(
            "منطقة محمية",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              SizedBox(height: 18),
              Text(
                "جاري التحقق من بيانات المالك...",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _indigoColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSubscriptionExpired) {
      return _buildExpiredScreen();
    }

    // ignore: unused_local_variable
    final bool isStoreActive =
        _liveUser.storePublishDate != null &&
        _liveUser.storePublishDate!.trim().isNotEmpty &&
        _liveUser.storePublishDate != "null" &&
        !_isSubscriptionExpired;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _primaryColor,
          title: const Text(
            "إدارة المتجر الرقمي",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.fingerprint, color: Colors.white),
              tooltip: "التوقيع الرقمي",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DigitalSignatureScreen(
                      currentUser: _liveUser,
                      user: _liveUser,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.remove_red_eye, color: Colors.white),
              tooltip: "معاينة",
              onPressed: _openStorePreview,
            ),
          ],
        ),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primaryColor, _darkColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront,
                            color: _darkColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "متجرك الرقمي",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _storeNameController.text.trim().isEmpty
                                    ? "المتجر الرقمي"
                                    : _storeNameController.text.trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storeNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "١- اسم المتجر",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "يرجى إدخال اسم المتجر"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _businessCategoryController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "٢- المجال التجاري",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "يرجى تحديد المجال التجاري"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "٣- هاتف المتجر",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) => (v == null || v.trim().length < 8)
                        ? "يرجى إدخال رقم هاتف صحيح"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 256,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "٤- وصف المتجر — 256 حرف كحد أقصى",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "يرجى كتابة وصف المتجر"
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final bool hasSubscription =
                          _liveUser.storePublishDate != null &&
                          _liveUser.storePublishDate!.trim().isNotEmpty &&
                          _liveUser.storePublishDate != "null";
                      final bool subscriptionActive =
                          hasSubscription && !_isSubscriptionExpired;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: subscriptionActive
                              ? Colors.green.shade50
                              : Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: subscriptionActive
                                ? Colors.green
                                : _primaryColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      subscriptionActive
                                          ? Icons.check_circle
                                          : Icons.timer,
                                      color: subscriptionActive
                                          ? Colors.green
                                          : _darkColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      subscriptionActive
                                          ? "المتجر يعمل"
                                          : "المتجر جاهز للتشغيل",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: subscriptionActive
                                            ? Colors.green.shade800
                                            : _darkColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (subscriptionActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "متبقي ${_getRemainingDays()} يوم",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (!hasSubscription) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  "المتجر جاهز بالكامل. اضغط الزر أدناه عندما تريد بدء مدة الاشتراك. ستبدأ الـ365 يوماً من لحظة الضغط.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _startSubscription,
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "🚀 بدء تشغيل المتجر — 365 يوماً",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (subscriptionActive) ...[
                              const SizedBox(height: 8),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "✓ الاشتراك فعال ويمكنك الآن حفظ ونشر المتجر.",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _primaryColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🔗 رابط المتجر الرقمي",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _darkColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _linkController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                              ),
                              onPressed: _copyStoreLink,
                              child: const Icon(
                                Icons.copy,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "🛒 المنتجات والخدمات",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _darkColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "فعّل البطاقات التي تريد ظهورها في المتجر العام.",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  ..._resolvedCards.map(
                    (cardData) => _buildMarketingCard(cardData),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: _primaryColor),
                    ),
                    onPressed: _openStorePreview,
                    icon: const Icon(Icons.visibility, color: _darkColor),
                    label: const Text(
                      "معاينة المتجر قبل النشر",
                      style: TextStyle(
                        color: _darkColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🚀 زر الحفظ والتحديث والنشر الدائم طوال الـ 365 يوماً
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: _isPublishing
                        ? null
                        : _publishStore, // متاح دائماً للتعديل والنشر طوال فترة الاشتراك دون أن يختفي
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud_upload, color: Colors.white),
                    label: Text(
                      _isPublishing
                          ? "جاري الحفظ والنشر..."
                          : "💾 حفظ وتحديث ونشر المتجر",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Center(
                    child: Text(
                      "MOX Digital App • المنظومة أونلاين",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (_isPublishing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
