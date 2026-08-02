// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart'; // الخزينة السيادية لجلب بيانات العميل الحقيقية
import 'welcome_screen.dart';

class ExternalStoreFrontScreen extends StatefulWidget {
  final UserModel? user;
  final List<Map<String, dynamic>> clientCards;
  final String? directMoxId;
  final double? height;

  const ExternalStoreFrontScreen({
    super.key,
    this.user,
    this.clientCards = const [],
    this.directMoxId,
    this.height,
  });

  @override
  State<ExternalStoreFrontScreen> createState() =>
      _ExternalStoreFrontScreenState();
}

class _ExternalStoreFrontScreenState extends State<ExternalStoreFrontScreen> {
  UserModel? _resolvedUser;
  late List<Map<String, dynamic>> _resolvedCards;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStoreData();
  }

  // دالة ذكية ومحصنة بالكامل لتحليل الـ URL أو تحديث البيانات من الخزينة السيادية
  Future<void> _initializeStoreData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    UserModel? userToUse = widget.user;
    List<Map<String, dynamic>> cardsToUse = List<Map<String, dynamic>>.from(
      widget.clientCards,
    );
    String? targetMoxId = widget.directMoxId;

    try {
      // التأكد من جاهزية الخزينة السيادية أولاً
      await StorageService.ensureLoaded();

      // جلب أحدث نسخة للمستخدم بالاعتماد على moxId حصرياً
      if (userToUse != null) {
        UserModel? freshUser;
        try {
          if (userToUse.moxId.isNotEmpty && userToUse.moxId != "لم يحدد") {
            freshUser = await StorageService.getUserByMoxId(userToUse.moxId);
          }
        } catch (_) {}
        userToUse = freshUser ?? userToUse;
      }

      // التقاط المعرف من الـ URL في حالة الويب
      if (userToUse == null && targetMoxId == null && kIsWeb) {
        try {
          final uri = Uri.base;
          targetMoxId =
              uri.queryParameters['mox'] ?? uri.queryParameters['phone'];
        } catch (_) {}
      }

      // جلب البيانات بالمعرف المستهدف إن وجد
      if (userToUse == null && targetMoxId != null && targetMoxId.isNotEmpty) {
        try {
          userToUse = await StorageService.getUserByMoxId(targetMoxId);
          final fetchedCards = await StorageService.getClientCards(targetMoxId);
          if (fetchedCards.isNotEmpty) {
            cardsToUse = List<Map<String, dynamic>>.from(fetchedCards);
          }
        } catch (_) {}
      }

      // تحويل آمن للأصول ومعالجة نماذج التسويق (MarketingCard) المسترجعة من زر النشر
      if (userToUse != null && userToUse.myAssets.isNotEmpty) {
        final List<Map<String, dynamic>> convertedAssets = [];
        for (final asset in userToUse.myAssets) {
          try {
            if (asset is Map<String, dynamic>) {
              convertedAssets.add(asset as Map<String, dynamic>);
            } else if (asset is Map) {
              convertedAssets.add(
                Map<String, dynamic>.from(asset as Map<dynamic, dynamic>),
              );
            } else if (asset != null) {
              final dynamic rawJson = (asset as dynamic).toJson();
              if (rawJson is Map) {
                convertedAssets.add(Map<String, dynamic>.from(rawJson));
              } else {
                convertedAssets.add({
                  'title': asset.toString(),
                  'description': 'أصل رقمي معتمد في منظومة موكس',
                  'price': 0.0,
                  'whatsapp': userToUse.phone,
                  'facebookUrl': '',
                });
              }
            }
          } catch (_) {}
        }
        if (convertedAssets.isNotEmpty) {
          cardsToUse = convertedAssets;
        }
      }
    } catch (_) {}

    _resolvedUser =
        userToUse ??
        UserModel(
          name: targetMoxId != null ? "متجر العميل الرقمي" : "العميل السيادي",
          phone: "0000000000",
          address: "المتجر الرقمي المفتوح",
          moxId: targetMoxId ?? "MOX-ACTIVE",
          password: "",
          balance: 0.0,
          gender: "غير محدد",
          accountType: "external",
        );

    _resolvedCards = cardsToUse.isNotEmpty
        ? cardsToUse
        : [
            {
              'title': 'بطاقة المتجر السيادي الافتراضية',
              'description':
                  'هذه البطاقة معتمدة وجاهزة للعرض التجاري الفاخر عبر الرابط المنسوخ للزوار.',
              'price': 0.0,
              'whatsapp': _resolvedUser!.phone,
              'facebookUrl': '',
            },
          ];

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _hasActiveStore(UserModel activeUser) {
    return activeUser.myAssets.isNotEmpty ||
        (activeUser.moxId.isNotEmpty && activeUser.moxId != "لم يحدد");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.height != null &&
        widget.user == null &&
        widget.directMoxId == null &&
        widget.clientCards.isEmpty &&
        !kIsWeb) {
      return Container(height: widget.height, color: Colors.transparent);
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF28A9CC),
          title: const Text(
            "جاري تحميل المتجر...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
        ),
      );
    }

    final UserModel resolvedUser = _resolvedUser!;
    final List<Map<String, dynamic>> activeCards = _resolvedCards;
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            }
          },
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
                          "🌟 السوق المفتوح والواجهة السيادية المعتمدة",
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
                          "معرف MOX: ${resolvedUser.moxId}",
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
                    "🛒 البطاقات والأصول المنشورة عبر لوحة التحكم (الصفحة A):",
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
                                    card['title']?.toString() ?? "بطاقة سيادية",
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
                              card['description']?.toString() ?? "",
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
                                          card['whatsapp']?.toString() ??
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
                                      "طلب عبر واتساب",
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
                                      final detailsUrl =
                                          card['facebookUrl']?.toString() ??
                                          card['facebook']?.toString() ??
                                          "";
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
                          "عفواً.. هذا المتجر لم يتم نشره وتفعيل أصوله بعد عبر لوحة التحكم (الصفحة A)🤚",
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
                            "العودة لتسجيل الدخول والاعتماد",
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

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: content);
    }

    return content;
  }
}
