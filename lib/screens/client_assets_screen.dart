// ignore_for_file: dead_code, unnecessary_type_check, duplicate_ignore, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'welcome_screen.dart';

class ClientAssetsScreen extends StatefulWidget {
  final UserModel user;
  const ClientAssetsScreen({super.key, required this.user});

  @override
  State<ClientAssetsScreen> createState() => _ClientAssetsScreenState();
}

class _ClientAssetsScreenState extends State<ClientAssetsScreen> {
  bool isActivatingStore = false;

  Map<String, dynamic> _parseAsset(dynamic rawAsset) {
    if (rawAsset == null) {
      return {
        'title': 'بطاقة رقمية',
        'description': '',
        'price': 0.0,
        'whatsapp': widget.user.phone,
        'facebook': '',
        'isApproved': false,
      };
    }
    if (rawAsset is Map<String, dynamic>) return rawAsset;
    if (rawAsset is Map) return Map<String, dynamic>.from(rawAsset);
    try {
      if (rawAsset.runtimeType.toString().contains('MarketingCard')) {
        return (rawAsset as dynamic).toJson();
      }
      final dyn = rawAsset as dynamic;
      return {
        'title': dyn.title?.toString() ?? 'بطاقة رقمية',
        'description': dyn.description?.toString() ?? '',
        'price': dyn.price ?? 0.0,
        'whatsapp': dyn.whatsapp?.toString() ?? widget.user.phone,
        'facebook': dyn.facebookUrl?.toString() ?? '',
        'isApproved': dyn.isApproved ?? false,
      };
    } catch (_) {
      return {
        'title': rawAsset.toString(),
        'description': 'مستند رقمي معتمد في منظومة موكس',
        'price': 0.0,
        'whatsapp': widget.user.phone,
        'facebook': '',
        'isApproved': false,
      };
    }
  }

  Future<void> _requestStoreActivation() async {
    setState(() {
      isActivatingStore = true;
    });

    try {
      if (widget.user.storePublishDate == null ||
          widget.user.storePublishDate!.isEmpty) {
        widget.user.storePublishDate = DateTime.now().toIso8601String();
      }

      await StorageService.updateUserPartial(widget.user);
      await StorageService.saveUsersList();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🚀 تم إرسال طلب تنشيط المتجر بنجاح إلى لوحة المدير السيادية (365 يوماً)",
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ حدث خطأ أثناء إرسال الطلب: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isActivatingStore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final rawAssetsData = widget.user.myAssets;
    // ignore: unnecessary_null_comparison
    final List<dynamic> realAssets = rawAssetsData != null
        ? (rawAssetsData is List ? rawAssetsData : [rawAssetsData])
        : [];

    final bool isStoreActive = widget.user.role == 'reviewed_active';

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
                        const SizedBox(height: 4),
                        Text(
                          "حالة المتجر: ${isStoreActive ? 'نشط ومعتمد (365 يوم)' : 'بانتظار المراجعة والتنشيط'}",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
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
                      "⚠️ لم تتم ترقية حساب العميل برقم MOX سيادي",
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🛒 بطاقات ومستندات المتجر (${realAssets.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.indigo,
                  ),
                ),
                if (isStoreActive)
                  const Chip(
                    backgroundColor: Colors.green,
                    label: Text(
                      "متجر نشط ومعتمد",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (realAssets.isEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    "لا توجد بطاقات أو مستندات موثقة مسجلة لهذا العميل حالياً.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...realAssets.map((rawAsset) {
                final card = _parseAsset(rawAsset);
                final String phone =
                    (card['whatsapp'] != null &&
                        card['whatsapp'].toString().isNotEmpty)
                    ? card['whatsapp'].toString()
                    : widget.user.phone;
                final double price = card['price'] != null
                    ? (card['price'] is double
                          ? card['price']
                          : double.tryParse(card['price'].toString()) ?? 0.0)
                    : 0.0;

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
                                card['title']?.toString() ?? 'بطاقة بدون عنوان',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            if (price > 0)
                              Text(
                                "$price ج.س",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card['description']?.toString() ?? '',
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final url = Uri.parse("https://wa.me/$phone");
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
                            if (card['facebook'] != null &&
                                card['facebook']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final url = Uri.parse(
                                      card['facebook'].toString(),
                                    );
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
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFF28A9CC), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isActivatingStore ? null : _requestStoreActivation,
              icon: isActivatingStore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF28A9CC),
                    ),
              label: Text(
                isActivatingStore
                    ? "جاري إرسال الطلب..."
                    : "تنشيط المتجر (365 يوم)",
                style: const TextStyle(
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
