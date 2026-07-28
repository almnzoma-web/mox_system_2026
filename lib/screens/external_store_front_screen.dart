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
  final String? directPhone;
  final double? height;

  const ExternalStoreFrontScreen({
    super.key,
    this.user,
    this.clientCards = const [],
    this.directPhone,
    this.height,
  });

  @override
  State<ExternalStoreFrontScreen> createState() =>
      _ExternalStoreFrontScreenState();
}

class _ExternalStoreFrontScreenState extends State<ExternalStoreFrontScreen> {
  late UserModel? _resolvedUser;
  late List<Map<String, dynamic>> _resolvedCards;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStoreData();
  }

  // دالة ذكية لتحليل الـ URL على الويب واستخراج الهاتف، أو جلب البيانات مباشرة
  Future<void> _initializeStoreData() async {
    setState(() {
      _isLoading = true;
    });

    UserModel? userToUse = widget.user;
    List<Map<String, dynamic>> cardsToUse = widget.clientCards;
    String? targetPhone = widget.directPhone;

    // إذا كنا نعمل على الويب ولم يتم تمرير المستخدم مباشرة، نقوم بقراءة الباراميتر من الـ URL (مثل ?phone=...)
    if (userToUse == null && targetPhone == null && kIsWeb) {
      try {
        // استخراج الـ Uri الحالي للـ Web
        final uri = Uri.base;
        targetPhone = uri.queryParameters['phone'];
      } catch (_) {}
    }

    // إذا وجدنا رقم هاتف قادم من الرابط الخارجي، نسحب بيانات العميل وبطاقاته من الخزينة السيادية!
    if (userToUse == null && targetPhone != null && targetPhone.isNotEmpty) {
      try {
        // استدعاء الخزينة لجلب ملف العميل الحقيقي بواسطة الهاتف
        userToUse = await StorageService.getUserByPhone(targetPhone);
        // استدعاء بطاقات العميل الخاصة من الخزينة
        cardsToUse = await StorageService.getClientCards(targetPhone);
      } catch (_) {}
    }

    // إذا لم نجد العميل، نقوم ببناء كائن افتراضي آمن بالهاتف المستهدف لكي لا ينكسر التطبيق
    _resolvedUser =
        userToUse ??
        UserModel(
          name: targetPhone != null ? "متجر العميل الرقمي" : "العميل السيادي",
          phone: targetPhone ?? "0000000000",
          address: "المتجر الرقمي المفتوح",
          moxId: targetPhone != null ? "MOX-WEB-ACTIVE" : "MOX-ACTIVE",
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
              'facebook': '',
            },
          ];

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
    if (widget.height != null &&
        widget.user == null &&
        widget.directPhone == null &&
        widget.clientCards.isEmpty &&
        !kIsWeb) {
      return Container(height: widget.height, color: Colors.transparent);
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF28A9CC),
          title: const Text(
            "جاري تحميل المتجر السيادي...",
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
                    "🛒 العروض والبطاقات النشطة للعميل (متاحة للعامة)",
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
                                      "طلب منتج/خدمة عبر واتساب",
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

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: content);
    }

    return content;
  }
}
