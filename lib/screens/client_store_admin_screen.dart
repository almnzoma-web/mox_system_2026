// ignore_for_file: use_build_context_synchronously

// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../data/user_data.dart';
import '../services/storage_service.dart';
import 'digital_signature_screen.dart';
import '../widgets/store_preview_widget.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;
  const ClientStoreAdminScreen({
    super.key,
    required this.user,
    required String directMoxId,
    required List<Map<String, dynamic>> clientCards,
  });

  @override
  State<ClientStoreAdminScreen> createState() => _ClientStoreAdminScreenState();
}

class _ClientStoreAdminScreenState extends State<ClientStoreAdminScreen> {
  // 🔑 رقم التنشيط السيادي (مكون من 21 خانة)
  static const String _sovereignActivationKey = "MOX-2026-KEY-9876543210AB";

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _businessCategoryController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // 🏛️ التوليد الداخلي السيادي البحت للبطاقات الـ 5 بالمسطرة دون أي ارتباط بشاشات خارجية
  late final List<Map<String, dynamic>> _resolvedCards = [
    {
      "title": "البطاقة السيادية الأولى للمتجر",
      "description":
          "الوصف الهندسي للبطاقة الأولى ويغطي كافة تفاصيل العرض الأساسي بالمسطرة.",
      "price": 1000.0,
      "category": "بطاقة",
    },
    {
      "title": "البطاقة السيادية الثانية للمتجر",
      "description":
          "الوصف الهندسي للبطاقة الثانية ويغطي كافة تفاصيل العرض الفرعي بالمسطرة.",
      "price": 2000.0,
      "category": "بطاقة",
    },
    {
      "title": "القسم السيادي الثالث للمتجر",
      "description":
          "الوصف الهندسي للقسم الثالث ويغطي تصنيفات المنتجات والخدمات الكبرى.",
      "price": 3000.0,
      "category": "قسم",
    },
    {
      "title": "الرف السيادي الرابع للمتجر",
      "description":
          "الوصف الهندسي للرف الرابع ويغطي عرض المنتجات المميزة والخاصة.",
      "price": 4000.0,
      "category": "رف",
    },
    {
      "title": "البطاقة السيادية الخامسة للمتجر",
      "description":
          "الوصف الهندسي للبطاقة الخامسة وتختتم حزمة الأصول التسويقية والخدمية.",
      "price": 5000.0,
      "category": "بطاقة",
    },
  ];

  final Map<String, bool> _cardActivationStatus = {};
  final Map<String, String> _cardCategories = {};

  final Map<String, TextEditingController> _cardTitleControllers = {};
  final Map<String, TextEditingController> _cardDescControllers = {};
  final Map<String, TextEditingController> _cardPriceControllers = {};
  final Map<String, TextEditingController> _cardCustomControllers = {};

  bool _isAuthorized = false;
  bool _isPublishing = false;
  int _activationButtonState = 0;
  bool _isSubscriptionExpired = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone;

    if (widget.user.name.isNotEmpty) {
      _storeNameController.text = widget.user.name;
    }

    if (widget.user.address.isNotEmpty) {
      _businessCategoryController.text = widget.user.address;
    }

    if (widget.user.myAssets.isNotEmpty) {
      try {
        final firstAsset = widget.user.myAssets.first;
        _descriptionController.text = firstAsset.description;
      } catch (_) {}
    }

    _linkController.text =
        "https://mox-system.web.app/?mox=${widget.user.moxId}";

    // تهيئة حالات التفعيل والمتحكمات الداخلية بناءً على القائمة المولدة محلياً 100%
    for (var card in _resolvedCards) {
      String title = card['title'].toString();
      bool isAlreadyActive = widget.user.myAssets.any(
        (asset) => asset.title == title,
      );
      _cardActivationStatus[title] = isAlreadyActive;
      _cardCategories[title] = card['category'] ?? 'بطاقة';

      _cardTitleControllers[title] = TextEditingController(text: title);
      _cardDescControllers[title] = TextEditingController(
        text: card['description'] ?? '',
      );
      _cardPriceControllers[title] = TextEditingController(
        text: (card['price'] ?? 0.0).toString(),
      );
      _cardCustomControllers[title] = TextEditingController(
        text: card['customField'] ?? '',
      );
    }

    if (widget.user.storePublishDate != null &&
        widget.user.storePublishDate!.isNotEmpty) {
      if (_checkIf365DaysExpired(widget.user.storePublishDate)) {
        _isSubscriptionExpired = true;
        _activationButtonState = 0;
      } else {
        _isSubscriptionExpired = false;
        _activationButtonState = 1;
      }
    } else {
      _isSubscriptionExpired = false;
      _activationButtonState = 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSecurityLoginDialog();
      if (_isSubscriptionExpired) {
        _showActivationKeyDialog();
      }
    });
  }

  bool _checkIf365DaysExpired(String? publishDateStr) {
    if (publishDateStr == null || publishDateStr.isEmpty) return false;
    try {
      DateTime publishDate = DateTime.parse(publishDateStr);
      DateTime expiryDate = publishDate.add(const Duration(days: 365));
      return DateTime.now().isAfter(expiryDate);
    } catch (_) {
      return false;
    }
  }

  void _showActivationKeyDialog() {
    final TextEditingController keyController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "انتهت صلاحية المتجر (٣٦٥ يوماً)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "المتجر مغلق حالياً. أدرج رقم التنشيط المكون من ٢١ خانة لإعادة تفعيل المتجر لـ ٣٦٥ يوماً جديدة بالمسطرة:",
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: keyController,
              maxLength: 25,
              decoration: const InputDecoration(
                labelText: "رقم التنشيط السيادي (٢١ خانة)",
                border: OutlineInputBorder(),
                isDense: true,
                counterText: "",
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A9CC),
            ),
            onPressed: () async {
              String enteredKey = keyController.text.trim();

              if (enteredKey == _sovereignActivationKey) {
                Navigator.pop(ctx);
                setState(() {
                  _isSubscriptionExpired = false;
                  _activationButtonState = 1;
                  for (var key in _cardActivationStatus.keys) {
                    _cardActivationStatus[key] = true;
                  }
                });

                UserModel renewedUser = widget.user.copyWith(
                  storePublishDate: DateTime.now().toIso8601String(),
                  role: 'reviewed_active',
                );
                await StorageService.updateUserPartial(renewedUser);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ تم قبول رقم التنشيط بنجاح! عاد المتجر للحياة لـ 365 يوماً.",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "❌ رقم التنشيط غير صحيح.. تأكد من الـ 21 خانة بالمسطرة!",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "تفعيل المتجر",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _businessCategoryController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    for (var c in _cardTitleControllers.values) {
      c.dispose();
    }
    for (var c in _cardDescControllers.values) {
      c.dispose();
    }
    for (var c in _cardPriceControllers.values) {
      c.dispose();
    }
    for (var c in _cardCustomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showSecurityLoginDialog() async {
    await StorageService.ensureLoaded();

    final TextEditingController moxInputController = TextEditingController();
    final TextEditingController passwordInputController =
        TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Color(0xFF28A9CC)),
            SizedBox(width: 8),
            Text(
              "التحقق برقم موكس وكلمة السر",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "أدخل رقم موكس الخاص بك وكلمة السر بالمسطرة:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moxInputController,
              decoration: const InputDecoration(
                labelText: "أدرج رقم موكس (MOX)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordInputController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة السر",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A9CC),
            ),
            onPressed: () async {
              String enteredMox = moxInputController.text.trim();
              String enteredPassword = passwordInputController.text.trim();

              bool isMoxMatchedInProfile = false;
              bool isPasswordMatched = false;

              try {
                bool matchesUserMox =
                    (widget.user.moxId.trim().toUpperCase() ==
                        enteredMox.toUpperCase()) ||
                    (widget.user.guardianMoxId != null &&
                        widget.user.guardianMoxId!.trim().toUpperCase() ==
                            enteredMox.toUpperCase());

                if (enteredMox.isNotEmpty && matchesUserMox) {
                  isMoxMatchedInProfile = true;
                } else {
                  for (var u in registeredUsers) {
                    bool matchesStorageMox =
                        (u.moxId.trim().toUpperCase() ==
                            enteredMox.toUpperCase()) ||
                        (u.guardianMoxId != null &&
                            u.guardianMoxId!.trim().toUpperCase() ==
                                enteredMox.toUpperCase());
                    if (matchesStorageMox && enteredMox.isNotEmpty) {
                      isMoxMatchedInProfile = true;
                      break;
                    }
                  }
                }

                if (isMoxMatchedInProfile) {
                  if (widget.user.password == enteredPassword &&
                      enteredPassword.isNotEmpty) {
                    isPasswordMatched = true;
                  } else {
                    for (var u in registeredUsers) {
                      bool matchesStorageMox =
                          (u.moxId.trim().toUpperCase() ==
                              enteredMox.toUpperCase()) ||
                          (u.guardianMoxId != null &&
                              u.guardianMoxId!.trim().toUpperCase() ==
                                  enteredMox.toUpperCase());
                      if (matchesStorageMox &&
                          u.password == enteredPassword &&
                          enteredPassword.isNotEmpty) {
                        isPasswordMatched = true;
                        break;
                      }
                    }
                  }
                }
              } catch (_) {
                isMoxMatchedInProfile = false;
                isPasswordMatched = false;
              }

              if (!mounted) return;
              Navigator.pop(ctx);

              if (!isMoxMatchedInProfile || !isPasswordMatched) {
                setState(() {
                  _isAuthorized = false;
                });
                _showLuxuryErrorDialog();
              } else {
                setState(() {
                  _isAuthorized = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ تم التحقق بنجاح - مرحباً بك في سيادة الدكان",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              "تحقق معتمد",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLuxuryErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "خطأ في التحقق والاعتماد السيادي",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: const Text(
          "عفواً.. رقم موكس غير مطابق أو كلمة السر غير صحيحة ✋",
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A9CC),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("حسناً", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleActivationButtonPress() async {
    if (_activationButtonState == 0) {
      setState(() {
        _activationButtonState = 1;
        for (var key in _cardActivationStatus.keys) {
          _cardActivationStatus[key] = true;
        }
      });

      UserModel tempUser = widget.user.copyWith(
        storePublishDate: DateTime.now().toIso8601String(),
        role: 'reviewed_active',
      );
      await StorageService.updateUserPartial(tempUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "✅ تم بدء حساب الـ 365 يوماً وتنشيط البطاقات الـ 5 بالمسطرة",
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _openStorePreview() {
    if (_isSubscriptionExpired) {
      _showActivationKeyDialog();
      return;
    }

    UserModel liveUser = widget.user.copyWith(
      name: _storeNameController.text.trim(),
      address: _businessCategoryController.text.trim(),
      phone: _phoneController.text.trim(),
      storeDescription: _descriptionController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (context) => StorePreviewWidget(
        user: liveUser,
        allCards: _resolvedCards,
        activeStatus: _cardActivationStatus,
      ),
    );
  }

  Future<void> _publishStore() async {
    if (!_isAuthorized) {
      _showSecurityLoginDialog();
      return;
    }

    if (_isSubscriptionExpired) {
      _showActivationKeyDialog();
      return;
    }

    if (_formKey.currentState!.validate()) {
      List<MarketingCard> updatedAssets = [];

      for (var cardData in _resolvedCards) {
        String title = cardData['title'].toString();
        bool isChecked = _cardActivationStatus[title] ?? false;

        if (isChecked &&
            (_activationButtonState == 1 ||
                widget.user.role == 'reviewed_active')) {
          try {
            var cardModel = MarketingCard.fromJson(cardData);
            updatedAssets.add(
              cardModel.copyWith(
                title: _cardTitleControllers[title]?.text.trim() ?? title,
                description:
                    _cardDescControllers[title]?.text.trim() ??
                    _descriptionController.text.trim(),
                price:
                    double.tryParse(
                      _cardPriceControllers[title]?.text.trim() ?? '0',
                    ) ??
                    0.0,
                whatsapp: _phoneController.text.trim(),
                isApproved: true,
              ),
            );
          } catch (_) {
            updatedAssets.add(
              MarketingCard(
                title: title,
                description: _cardDescControllers[title]?.text.trim() ?? '',
                price:
                    double.tryParse(
                      _cardPriceControllers[title]?.text.trim() ?? '0',
                    ) ??
                    0.0,
                whatsapp: _phoneController.text.trim(),
                facebookUrl: '',
                isApproved: true,
              ),
            );
          }
        }
      }

      if (updatedAssets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ تنبيه: يجب تفعيل بطاقة واحدة على الأقل بعلامة صح.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        _isPublishing = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      String finalPublishTimestamp =
          (widget.user.storePublishDate != null &&
              widget.user.storePublishDate!.isNotEmpty &&
              !_checkIf365DaysExpired(widget.user.storePublishDate))
          ? widget.user.storePublishDate!
          : DateTime.now().toIso8601String();

      UserModel updatedUser = widget.user.copyWith(
        name: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _businessCategoryController.text.trim(),
        myAssets: updatedAssets,
        storePublishDate: finalPublishTimestamp,
        role: 'reviewed_active',
      );

      await StorageService.updateUserPartial(updatedUser);

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 تم تحديث ونشر المتجر بنجاح بالمسطرة"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, updatedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text(
            "منطقة مقفلة برهون الاعتماد",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            "جاري التحقق برقم موكس وكلمة السر...",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        ),
      );
    }

    if (_isSubscriptionExpired) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: const Text(
            "المتجر مغلق - انتهت صلاحية الـ ٣٦٥ يوماً",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  "المتجر سوف يعود قريباً بعد تنشيطه من قبل العميل المالك ✋",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "يرجى إدخال رقم التنشيط المكون من ٢١ خانة لإعادة تشغيله بالمسطرة.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A9CC),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _showActivationKeyDialog,
                  icon: const Icon(Icons.vpn_key, color: Colors.white),
                  label: const Text(
                    "إدخال رقم التنشيط (٢١ خانة)",
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
      );
    }

    bool isStoreActive =
        (_activationButtonState == 1 || widget.user.role == 'reviewed_active');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: const Text(
          "إدارة المتجر السيادي والبطاقات الـ 5 الداخلية",
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
            icon: const Icon(Icons.remove_red_eye, color: Colors.white),
            tooltip: "معاينة المتجر المنبثقة",
            onPressed: _openStorePreview,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    "🛒 إعدادات المتجر السيادي وإدارة البطاقات الـ 5 المبتكرة محلياً بالكامل",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(
                      labelText: "١- اسم الدكان/المتجر (إلزامي)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? "يرجى إدخال اسم الدكان"
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _businessCategoryController,
                    decoration: const InputDecoration(
                      labelText: "٢- المجال التجاري (إلزامي)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? "يرجى تحديد المجال التجاري"
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "٤- هاتف اتصال (إلزامي)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) => val == null || val.length < 10
                        ? "يرجى إدخال هاتف صحيح"
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 256,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "٥- وصف المتجر في حدود ٢٥٦ حرف (إلزامي)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? "يرجى كتابة وصف موجز"
                        : null,
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF28A9CC),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🔗 رابط المتجر الرقمي السيادي (للمشاركة والمعاينة):",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF1B6B80),
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
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF28A9CC),
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _linkController.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "📋 تم نسخ الرابط بنجاح بالمسطرة!",
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text(
                                "نسخ",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "٦- إدارة البطاقات الـ 5 المولدة داخلياً بالمسطرة:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Column(
                    children: _resolvedCards.map((cardData) {
                      String titleKey = cardData['title'].toString();
                      bool isChecked = _cardActivationStatus[titleKey] ?? false;
                      String currentCategory =
                          _cardCategories[titleKey] ?? 'بطاقة';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isChecked
                                ? const Color(0xFF28A9CC)
                                : Colors.grey.shade300,
                            width: isChecked ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF28A9CC,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButton<String>(
                                      value: currentCategory,
                                      underline: const SizedBox(),
                                      isDense: true,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B6B80),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'بطاقة',
                                          child: Text('بطاقة'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'قسم',
                                          child: Text('قسم'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'رف',
                                          child: Text('رف'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _cardCategories[titleKey] = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        "تنشيط البطاقة",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Checkbox(
                                        value: isChecked,
                                        activeColor: const Color(0xFF28A9CC),
                                        onChanged: isStoreActive
                                            ? (bool? val) {
                                                setState(() {
                                                  _cardActivationStatus[titleKey] =
                                                      val ?? false;
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              TextFormField(
                                controller: _cardTitleControllers[titleKey],
                                decoration: const InputDecoration(
                                  labelText: "عنوان البطاقة / العرض",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _cardDescControllers[titleKey],
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: "وصف البطاقة التفصيلي",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                          _cardPriceControllers[titleKey],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: "السعر (ج.س)",
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B6B80),
                                      minimumSize: const Size(100, 42),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "⚡ تم حفظ تعديل البطاقة: ${_cardTitleControllers[titleKey]?.text}",
                                          ),
                                          backgroundColor: Colors.teal,
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.bolt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      "تحديث",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DigitalSignatureScreen(
                              currentUser: widget.user,
                            ),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.gesture_rounded,
                              color: Color(0xFF1B6B80),
                              size: 28,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "بوابة التوقيع الرقمي السيادي",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1B6B80),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "اعتمد عقودك ومستنداتك بتوقيع رقمي موثق بالمسطرة",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Color(0xFF1B6B80),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStoreActive
                          ? Colors.green
                          : const Color(0xFF1B6B80),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleActivationButtonPress,
                    child: Text(
                      _activationButtonState == 0
                          ? "طلب تنشيط (بدء حساب ٣٦٥ يوماً)"
                          : "نشط (معتمد ومفعل للـ ٣٦٥ يوماً ✅)",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A9CC),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isPublishing ? null : _publishStore,
                    icon: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "نشر وتحديث المتجر بالبطاقات المفعلة فقط",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isPublishing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Color(0xFF28A9CC)),
                      SizedBox(height: 18),
                      Text(
                        "جاري حفظ وتثبيت النسخة المعتمدة لمتجرك...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
