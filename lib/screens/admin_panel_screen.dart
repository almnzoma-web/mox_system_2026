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

  // حالة التفويض المحلية الخاصة بالدخول (افتراضياً غير مسموح حتى يتم التحقق)
  // ignore: unused_field
  bool _isAuthorized = false;

  // ============================================================
  // ☁️ Google Apps Script
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwJCjg5WOUPCS4EgolxAhmX-BrbW7JCy32FM0Xht3GgesEuaJL0Cf5UyRfe8ZXnCITu/exec';

  // ============================================================
  // 🔗 رابط العميل العام
  // ============================================================

  String _buildClientStoreLink(UserModel user) {
    final String guardianMoxId = (user.guardianMoxId ?? '')
        .trim()
        .toUpperCase();

    if (!_isValidGuardianMoxId(guardianMoxId)) {
      return '';
    }

    final String encodedGuardianMoxId = Uri.encodeComponent(guardianMoxId);

    return 'https://mox-2026.vercel.app/store/$encodedGuardianMoxId';
  }

  // ============================================================
  // 🔎 التحقق من guardianMoxId
  // ============================================================

  bool _isValidGuardianMoxId(String value) {
    final String normalized = value.trim().toUpperCase();

    if (normalized.isEmpty ||
        normalized == 'NULL' ||
        normalized == 'UNDEFINED' ||
        normalized == 'N/A' ||
        normalized == 'لم يحدد') {
      return false;
    }

    return true;
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
  // 🔐 نافذة تسجيل الدخول السيادية (محلي بالكامل ومقفل بالمسطرة)
  // ============================================================

  Future<void> _showSecurityLoginDialog(UserModel targetUser) async {
    final TextEditingController moxController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

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
              Icon(Icons.verified_user, color: Color(0xFF33A1C9)),
              SizedBox(width: 8),
              Text(
                "التحقق من صاحب المتجر",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "أدخل رقم MOX (الوصي) وكلمة السر الخاصة باشتراك العميل.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: moxController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "رقم MOX (الوصي)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "كلمة السر",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF33A1C9),
              ),
              onPressed: () {
                final String enteredMox = moxController.text
                    .trim()
                    .toUpperCase();
                final String enteredPassword = passwordController.text.trim();

                // إغلاق نافذة الدخول أولاً
                Navigator.pop(ctx);

                // --------------------------------------------------
                // الفحص السيادي المحلي الحصري (بدون أي اتصال أو بحث خارجي بـ Google)
                // --------------------------------------------------

                final String sessionGuardianMoxId =
                    (targetUser.guardianMoxId ?? '').trim().toUpperCase();
                final String sessionPassword = targetUser.password.trim();

                // مطابقة حصرياً لرقم الوصي وكلمة السر لبيانات هذا العميل في الجلسة المحلية
                final bool isMoxMatched =
                    sessionGuardianMoxId.isNotEmpty &&
                    (enteredMox == sessionGuardianMoxId);
                final bool isPasswordMatched =
                    sessionPassword.isNotEmpty &&
                    (enteredPassword == sessionPassword);

                // إذا لم تتطابق البيانات محلياً، تظهر رسالة الرفض الفاخرة فوراً
                if (!isMoxMatched || !isPasswordMatched) {
                  _showLuxuryAccessDeniedDialog();
                  return;
                }

                if (!mounted) return;

                // نجاح التحقق بالكامل
                setState(() {
                  _isAuthorized = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ تم التحقق بنجاح — مرحباً بك في إدارة الحساب.",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );

                // فتح لوحة التعديل أو المتابعة بعد النجاح
                _showEditClientDialog(targetUser);
              },
              child: const Text(
                "تحقق",
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
    passwordController.dispose();
  }

  // ============================================================
  // 🛡️ رسالة الرفض الفاخرة (السيادية) مع زر إغلاق حصراً
  // ============================================================

  void _showLuxuryAccessDeniedDialog() {
    if (!mounted) return;

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
              Icon(Icons.gpp_bad, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "عفواً، ليس لديك الصلاحيات",
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
            "عفواً ليس لديك الصلاحيات، رقم MOX (الوصي) أو كلمة السر غير مطابقة للبيانات المحلية.",
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "إغلاق",
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
  // ☁️ جلب العملاء من Google Sheets
  // ============================================================

  Future<void> _fetchFromCloud() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final Uri uri = Uri.parse(
        _scriptUrl,
      ).replace(queryParameters: {'action': 'getAll'});
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Google Apps Script HTTP ${response.statusCode}');
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is! List) {
        throw Exception('Google Apps Script لم يرجع List');
      }

      final List<UserModel> cloudClients = [];

      for (final dynamic item in decoded) {
        try {
          if (item is! Map) continue;

          final Map<String, dynamic> map = Map<String, dynamic>.from(item);

          if ((map['moxId'] == null ||
                  map['moxId'].toString().trim().isEmpty) &&
              map['MOXID'] != null) {
            map['moxId'] = map['MOXID'];
          }

          final UserModel user = UserModel.fromJson(map);
          cloudClients.add(user);
        } catch (e) {
          debugPrint('⚠️ [Admin Cloud] سجل غير صالح: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _clients = cloudClients;
      });
    } catch (e) {
      debugPrint('❌ [Admin Cloud] $e');

      try {
        await StorageService.loadUsers();

        if (!mounted) return;

        setState(() {
          _clients = List<UserModel>.from(StorageService.registeredUsers);
        });
      } catch (localError) {
        debugPrint('❌ [Admin Local] $localError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ☁️ حفظ العميل
  // ============================================================

  Future<void> _syncClientToCloud(UserModel user) async {
    try {
      await StorageService.updateUserPartial(user);

      if (!mounted) return;

      final String clientLink = _buildClientStoreLink(user);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clientLink.isNotEmpty
                ? '✅ تم حفظ ${user.name} وتحديث رابط العميل.'
                : '⚠️ تم حفظ ${user.name}، لكن guardianMoxId غير موجود.',
          ),
          backgroundColor: clientLink.isNotEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      await _fetchFromCloud();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حفظ بيانات العميل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 📋 نسخ رابط العميل
  // ============================================================

  Future<void> _copyClientStoreLink(UserModel user) async {
    final String link = _buildClientStoreLink(user);

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لا توجد guardianMoxId صالحة لهذا العميل.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 تم نسخ رابط العميل.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // ✏️ تعديل guardianMoxId
  // ============================================================

  void _showEditClientDialog(UserModel user) {
    final TextEditingController guardianMoxController = TextEditingController(
      text: user.guardianMoxId ?? '',
    );
    final TextEditingController moxIdController = TextEditingController(
      text: user.moxId,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final String previewGuardian = guardianMoxController.text
                .trim()
                .toUpperCase();
            final String previewLink = _isValidGuardianMoxId(previewGuardian)
                ? 'https://mox-2026.vercel.app/store/${Uri.encodeComponent(previewGuardian)}'
                : '';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'إدارة هوية العميل: ${user.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: guardianMoxController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'guardianMoxId — هوية MOX السيادية',
                        helperText:
                            'هذه الهوية هي الوحيدة المستخدمة في رابط العميل.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified_user),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: moxIdController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'moxId — الهوية التلقائية',
                        helperText:
                            'رقم تلقائي للعميل عند التسجيل ولا يدخل في الرابط العام.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 15),
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
                            '🔗 رابط العميل',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B6B80),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            previewLink.isNotEmpty
                                ? previewLink
                                : 'أدخل guardianMoxId لإنشاء رابط العميل',
                            style: TextStyle(
                              fontSize: 10,
                              color: previewLink.isNotEmpty
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
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
                  onPressed: () async {
                    final String newGuardianMoxId = guardianMoxController.text
                        .trim()
                        .toUpperCase();

                    user.guardianMoxId = newGuardianMoxId.isEmpty
                        ? null
                        : newGuardianMoxId;

                    Navigator.pop(dialogContext);
                    guardianMoxController.dispose();
                    moxIdController.dispose();

                    await _syncClientToCloud(user);
                  },
                  child: const Text(
                    'حفظ وتحديث الرابط',
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
          'لوحة تحكم المدير - السجل السيادي',
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
            tooltip: 'تحديث البيانات',
            onPressed: _fetchFromCloud,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: moxBlue))
          : _clients.isEmpty
          ? const Center(
              child: Text(
                'لا توجد سجلات عملاء مسجلة حالياً 📭',
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
                        'الاسم',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الهاتف',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'moxId',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'guardianMoxId',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'رابط العميل',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الرصيد',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'نوع الحساب',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الإجراءات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _clients.map((user) {
                    final String clientLink = _buildClientStoreLink(user);
                    final bool hasGuardian = _isValidGuardianMoxId(
                      (user.guardianMoxId ?? '').trim().toUpperCase(),
                    );

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(user.name.isNotEmpty ? user.name : 'بدون اسم'),
                        ),
                        DataCell(
                          Text(
                            user.phone.isNotEmpty ? user.phone : 'غير متوفر',
                          ),
                        ),
                        DataCell(
                          Text(user.moxId.isNotEmpty ? user.moxId : '---'),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => _showSecurityLoginDialog(user),
                            child: Text(
                              hasGuardian
                                  ? user.guardianMoxId!
                                  : 'اضغط للإضافة ⚙️',
                              style: TextStyle(
                                color: hasGuardian ? Colors.indigo : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          clientLink.isEmpty
                              ? const Text(
                                  'غير متاح',
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
                                        'نسخ الرابط',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        DataCell(Text(user.balance.toString())),
                        DataCell(
                          Text(
                            user.accountType.isNotEmpty
                                ? user.accountType
                                : 'عادي',
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: const Size(80, 32),
                                ),
                                onPressed: () => _showSecurityLoginDialog(user),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  'تعديل',
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
                                  'رحّل للشيت',
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
