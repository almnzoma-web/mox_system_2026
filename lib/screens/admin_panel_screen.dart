// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../services/storage_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final Color moxBlue = const Color(0xFF33A1C9);

  List<UserModel> _clients = [];
  bool _isLoading = true;

  // ============================================================
  // ☁️ رابط Google Apps Script المعتمد
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

  // ============================================================
  // 🔗 بناء رابط العميل
  //
  // نفس منطق المتجر العام:
  //
  // 1️⃣ guardianMoxId أولاً
  // 2️⃣ moxId كـ fallback
  //
  // الرابط النهائي:
  // https://mox-2026.vercel.app/#/?mox=IDENTIFIER
  //
  // مهم:
  // إذا كان guardianMoxId موجوداً فهو المستخدم الأساسي للرابط.
  // moxId لا يُستخدم إلا إذا لم توجد هوية guardian.
  // ============================================================

  String _buildClientStoreLink(UserModel user) {
    final String normalizedGuardian = (user.guardianMoxId ?? '')
        .trim()
        .toUpperCase();

    final String normalizedFallback = user.moxId.trim().toUpperCase();

    final String selectedIdentifier =
        normalizedGuardian.isNotEmpty &&
            normalizedGuardian != 'NULL' &&
            normalizedGuardian != 'لم يحدد'
        ? normalizedGuardian
        : normalizedFallback.isNotEmpty &&
              normalizedFallback != 'NULL' &&
              normalizedFallback != 'لم يحدد'
        ? normalizedFallback
        : '';

    if (selectedIdentifier.isEmpty) {
      return '';
    }

    return 'https://mox-2026.vercel.app/#/?mox=$selectedIdentifier';
  }

  // ============================================================
  // 🚀 INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fetchFromCloud();
  }

  // ============================================================
  // ☁️ جلب العملاء من Google
  // ============================================================

  Future<void> _fetchFromCloud() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http
          .get(Uri.parse(_scriptUrl))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        if (decoded is List) {
          final List<UserModel> cloudClients = decoded
              .map(
                (item) => UserModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();

          setState(() {
            _clients = cloudClients;
          });
        }
      }
    } catch (_) {
      // ========================================================
      // 🔄 fallback للمخزن المحلي / الهجين
      // ========================================================

      await StorageService.loadUsers();

      if (!mounted) return;

      setState(() {
        _clients = StorageService.registeredUsers;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // ☁️ ترحيل العميل إلى Google
  // ============================================================

  Future<void> _syncClientToCloud(UserModel user) async {
    try {
      // نحافظ على UserModel بالكامل
      // بما فيه myAssets و guardianMoxId.

      await StorageService.updateUserPartial(user);

      if (!mounted) return;

      // تحديث الرابط بعد نجاح الحفظ

      final String clientLink = _buildClientStoreLink(user);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clientLink.isNotEmpty
                ? "✅ تم تحديث بيانات ${user.name} والرابط السيادي بنجاح."
                : "✅ تم تحديث بيانات ${user.name} بنجاح. أضف هوية MOX لإنشاء الرابط.",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      await _fetchFromCloud();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ خطأ في الترحيل: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 🔗 نسخ رابط العميل
  // ============================================================

  Future<void> _copyClientStoreLink(UserModel user) async {
    final String link = _buildClientStoreLink(user);

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ لا توجد هوية MOX صالحة لهذا العميل حتى الآن."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 تم نسخ رابط العميل."),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // ✏️ تعديل بيانات العميل
  //
  // guardianMoxId:
  // المعرف السيادي اليدوي، وهو الأولوية في الرابط.
  //
  // moxId:
  // الهوية الأساسية، وتستخدم كـ fallback إذا لم يوجد
  // guardianMoxId.
  // ============================================================

  void _showEditClientDialog(UserModel user) {
    final TextEditingController guardianMoxController = TextEditingController(
      text: user.guardianMoxId ?? '',
    );

    final TextEditingController moxIdController = TextEditingController(
      text: user.moxId,
    );

    final String currentLink = _buildClientStoreLink(user);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "تعديل المعرف السيادي: ${user.name}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // guardianMoxId
                // ==================================================
                TextField(
                  controller: guardianMoxController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "معرف MOX السيادي اليدوي",
                    helperText: "هذا هو المعرف ذو الأولوية في رابط العميل.",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.verified_user),
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // moxId
                // ==================================================
                TextField(
                  controller: moxIdController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "معرف MOX الأساسي",
                    helperText: "يستخدم كبديل للرابط إذا لم توجد هوية سيادية.",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // رابط العميل الحالي
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: moxBlue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🔗 رابط العميل",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        currentLink.isNotEmpty
                            ? currentLink
                            : "سيظهر الرابط بعد إضافة هوية MOX",
                        style: TextStyle(
                          fontSize: 10,
                          color: currentLink.isNotEmpty
                              ? Colors.black87
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                guardianMoxController.dispose();

                moxIdController.dispose();

                Navigator.pop(dialogContext);
              },
              child: const Text("إلغاء"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
              onPressed: () async {
                final String newGuardianMoxId = guardianMoxController.text
                    .trim()
                    .toUpperCase();

                final String newMoxId = moxIdController.text.trim();

                // ==================================================
                // تحديث guardianMoxId
                // ==================================================

                user.guardianMoxId = newGuardianMoxId.isEmpty
                    ? null
                    : newGuardianMoxId;

                // ==================================================
                // moxId لا نغيره فعلياً
                // لأنه readOnly.
                //
                // فقط نحافظ على القيمة الحالية.
                // ==================================================

                if (newMoxId.isNotEmpty) {
                  user.moxId = newMoxId;
                }

                Navigator.pop(dialogContext);

                guardianMoxController.dispose();

                moxIdController.dispose();

                // ==================================================
                // حفظ كامل UserModel
                // ==================================================

                await _syncClientToCloud(user);
              },
              child: const Text(
                "حفظ وتحديث الرابط",
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
  }

  // ============================================================
  // 🌐 BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "لوحة تحكم المدير - السجل السيادي",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "تحديث البيانات",
            onPressed: _fetchFromCloud,
          ),
        ],
      ),

      // ==========================================================
      // 📋 BODY
      // ==========================================================
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: moxBlue))
          : _clients.isEmpty
          ? const Center(
              child: Text(
                "لا توجد سجلات عملاء مسجلة حالياً 📭",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(
                      label: Text(
                        "الاسم",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهاتف",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهوية الأساسية",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الهوية السيادية",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "رابط العميل",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الرصيد",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "نوع الحساب",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "الإجراء السيادي",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  rows: _clients.map((user) {
                    final String clientLink = _buildClientStoreLink(user);

                    return DataRow(
                      cells: [
                        // ==================================================
                        // الاسم
                        // ==================================================
                        DataCell(
                          Text(user.name.isNotEmpty ? user.name : "بدون اسم"),
                        ),

                        // ==================================================
                        // الهاتف
                        // ==================================================
                        DataCell(
                          Text(
                            user.phone.isNotEmpty ? user.phone : "غير متوفر",
                          ),
                        ),

                        // ==================================================
                        // moxId
                        // ==================================================
                        DataCell(
                          Text(user.moxId.isNotEmpty ? user.moxId : "---"),
                        ),

                        // ==================================================
                        // guardianMoxId
                        // ==================================================
                        DataCell(
                          InkWell(
                            onTap: () => _showEditClientDialog(user),
                            child: Text(
                              user.guardianMoxId?.isNotEmpty == true
                                  ? user.guardianMoxId!
                                  : "اضغط للإضافة ⚙️",
                              style: TextStyle(
                                color: user.guardianMoxId?.isNotEmpty == true
                                    ? Colors.indigo
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // ==================================================
                        // رابط العميل
                        // ==================================================
                        DataCell(
                          clientLink.isEmpty
                              ? const Text(
                                  "غير متاح",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 5),
                                    TextButton(
                                      onPressed: () =>
                                          _copyClientStoreLink(user),
                                      child: const Text(
                                        "نسخ الرابط",
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        // ==================================================
                        // الرصيد
                        // ==================================================
                        DataCell(Text(user.balance.toString())),

                        // ==================================================
                        // نوع الحساب
                        // ==================================================
                        DataCell(
                          Text(
                            user.accountType.isNotEmpty
                                ? user.accountType
                                : "عادي",
                          ),
                        ),

                        // ==================================================
                        // الإجراءات
                        // ==================================================
                        DataCell(
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: const Size(80, 32),
                                ),
                                onPressed: () => _showEditClientDialog(user),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  "تعديل",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: moxBlue,
                                  minimumSize: const Size(90, 32),
                                ),
                                onPressed: () => _syncClientToCloud(user),
                                icon: const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  "رحّل للشيت",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
