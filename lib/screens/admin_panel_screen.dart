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
  // ☁️ Google Apps Script
  // ============================================================

  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbykqj8mRpibT8S2aCVAOwM5DFFrp8VKHnbYtc-ITTh9pv4jVWlYjRsewNQYumsJTcfK/exec';

  // ============================================================
  // 🔗 رابط العميل العام
  //
  // مهم جداً:
  //
  // الرابط يعتمد على guardianMoxId فقط.
  //
  // guardianMoxId:
  // هوية MOX السيادية اليدوية التي يمنحها المدير.
  //
  // moxId:
  // رقم تلقائي للعميل عند التسجيل.
  // لا يدخل في الرابط العام.
  //
  // الرابط النهائي:
  //
  // https://mox-2026.vercel.app/store/MOX249-00010001
  //
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

    if (normalized.isEmpty) {
      return false;
    }

    if (normalized == 'NULL') {
      return false;
    }

    if (normalized == 'UNDEFINED') {
      return false;
    }

    if (normalized == 'N/A') {
      return false;
    }

    if (normalized == 'لم يحدد') {
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

      debugPrint('☁️ [Admin Cloud] HTTP: ${response.statusCode}');

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
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> map = Map<String, dynamic>.from(item);

          // ----------------------------------------------------
          // دعم اسم العمود القديم MOXID
          // ----------------------------------------------------

          if ((map['moxId'] == null ||
                  map['moxId'].toString().trim().isEmpty) &&
              map['MOXID'] != null) {
            map['moxId'] = map['MOXID'];
          }

          // ----------------------------------------------------
          // تحويل السجل إلى UserModel
          // ----------------------------------------------------

          final UserModel user = UserModel.fromJson(map);

          cloudClients.add(user);
        } catch (e) {
          debugPrint('⚠️ [Admin Cloud] سجل غير صالح: $e');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _clients = cloudClients;
      });

      debugPrint('✅ [Admin Cloud] تم تحميل ${cloudClients.length} عميل');
    } catch (e) {
      debugPrint('❌ [Admin Cloud] $e');

      // ========================================================
      // 🔄 fallback إلى التخزين المحلي
      // ========================================================

      try {
        await StorageService.loadUsers();

        if (!mounted) {
          return;
        }

        setState(() {
          _clients = List<UserModel>.from(StorageService.registeredUsers);
        });

        debugPrint('🔄 [Admin Local] تم استخدام البيانات المحلية');
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
      // --------------------------------------------------------
      // 1. الاستدعاء من قوقل شيت أولاً لجلب أحدث قيم (guardianMoxId و password)
      // --------------------------------------------------------
      try {
        // استخدام مسار الـ API الجديد على Vercel لجلب البيانات بأمان تام وبدون مشاكل CORS
        final Uri uri = Uri.parse('/api/store').replace(
          queryParameters: {
            'action': 'getAll',
            'guardianMoxId': user.guardianMoxId!.isNotEmpty
                ? user.guardianMoxId
                : user.moxId,
          },
        );
        final http.Response cloudResponse = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));

        if (cloudResponse.statusCode == 200) {
          final dynamic decoded = json.decode(cloudResponse.body);
          if (decoded is List) {
            for (final dynamic item in decoded) {
              if (item is Map) {
                final Map<String, dynamic> map = Map<String, dynamic>.from(
                  item,
                );
                final String cloudPhone = (map['phone'] ?? '')
                    .toString()
                    .trim();
                final String cloudMoxId = (map['moxId'] ?? map['MOXID'] ?? '')
                    .toString()
                    .trim();

                // مطابقة المستخدم بواسطة الهاتف أو الـ moxId الأساسي
                if ((user.phone.isNotEmpty && cloudPhone == user.phone) ||
                    (user.moxId.isNotEmpty && cloudMoxId == user.moxId)) {
                  // جلب وتحديث guardianMoxId من الشيت إذا وجد
                  final String cloudGuardian = (map['guardianMoxId'] ?? '')
                      .toString()
                      .trim();
                  if (cloudGuardian.isNotEmpty &&
                      cloudGuardian != 'null' &&
                      cloudGuardian != 'undefined') {
                    user.guardianMoxId = cloudGuardian;
                  }

                  // جلب وتحديث كلمة السر من الشيت إذا وجدت
                  final String cloudPassword = (map['password'] ?? '')
                      .toString()
                      .trim();
                  if (cloudPassword.isNotEmpty &&
                      cloudPassword != 'null' &&
                      cloudPassword != 'undefined') {
                    user.password = cloudPassword;
                  }

                  // جلب وتحديث تاريخ النشر من الشيت إذا وجد
                  final String cloudPublishDate =
                      (map['storePublishDate'] ?? '').toString().trim();
                  if (cloudPublishDate.isNotEmpty &&
                      cloudPublishDate != 'null' &&
                      cloudPublishDate != 'undefined') {
                    user.storePublishDate = cloudPublishDate;
                  }
                  break;
                }
              }
            }
          }
        }
      } catch (fetchError) {
        debugPrint(
          '⚠️ [Cloud Fetch Warning] لم يتم تحديث البيانات من السحابة قبل الحفظ: $fetchError',
        );
      }

      // --------------------------------------------------------
      // حفظ UserModel بالكامل
      // بما فيه guardianMoxId
      // --------------------------------------------------------

      await StorageService.updateUserPartial(user);

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حفظ بيانات العميل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 🔐 نافذة الفحص المنبثقة للتأكيد قبل التعديل
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
          title: Row(
            children: [
              Icon(Icons.verified_user, color: moxBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "فحص الهوية لإدارة العميل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "أدخل رقم موكس  وكلمة السر الخاصة بالعميل.",
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
              style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
              onPressed: () {
                final String enteredMox = moxController.text
                    .trim()
                    .toUpperCase();
                final String enteredPassword = passwordController.text.trim();

                final String userMox = targetUser.moxId.trim().toUpperCase();
                final String guardianMox = (targetUser.guardianMoxId ?? '')
                    .trim()
                    .toUpperCase();
                final String userPassword = (targetUser.password).trim();

                final bool moxMatched =
                    enteredMox.isNotEmpty &&
                    (enteredMox == userMox || enteredMox == guardianMox);
                final bool passwordMatched =
                    enteredPassword.isNotEmpty &&
                    enteredPassword == userPassword;

                Navigator.pop(ctx);

                if (!moxMatched || !passwordMatched) {
                  _showLuxuryErrorDialog();
                  return;
                }

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ تم التحقق بنجاح — يمكنك التعديل الآن."),
                    backgroundColor: Colors.green,
                  ),
                );

                _showEditClientDialog(targetUser);
              },
              child: const Text(
                "فحص",
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
  // ❌ خطأ الفحص
  // ============================================================

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
            "رقم موكس أو كلمة السر غير صحيحة.",
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("حسناً", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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

    if (!mounted) {
      return;
    }

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

    // moxId للعرض فقط
    final TextEditingController moxIdController = TextEditingController(
      text: user.moxId,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // --------------------------------------------------
            // قراءة guardianMoxId من الحقل مباشرة
            // --------------------------------------------------

            final String previewGuardian = guardianMoxController.text
                .trim()
                .toUpperCase();

            // --------------------------------------------------
            // الرابط يعتمد فقط على guardianMoxId
            // --------------------------------------------------

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
                    // ==================================================
                    // guardianMoxId
                    // ==================================================
                    TextField(
                      controller: guardianMoxController,

                      textCapitalization: TextCapitalization.characters,

                      onChanged: (_) {
                        setDialogState(() {});
                      },

                      decoration: const InputDecoration(
                        labelText: 'guardianMoxId — هوية MOX السيادية',

                        helperText:
                            'هذه الهوية هي الوحيدة المستخدمة في رابط العميل.',

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
                        labelText: 'moxId — الهوية التلقائية',

                        helperText:
                            'رقم تلقائي للعميل عند التسجيل ولا يدخل في الرابط العام.',

                        border: OutlineInputBorder(),

                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==================================================
                    // رابط العميل
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

                          const SizedBox(height: 8),

                          if (_isValidGuardianMoxId(previewGuardian))
                            const Text(
                              '✓ الرابط يستخدم guardianMoxId فقط',

                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const Text(
                              '⚠️ لا يوجد guardianMoxId صالح',

                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                // ==================================================
                // إلغاء
                // ==================================================
                TextButton(
                  onPressed: () {
                    guardianMoxController.dispose();
                    moxIdController.dispose();

                    Navigator.pop(dialogContext);
                  },

                  child: const Text('إلغاء'),
                ),

                // ==================================================
                // حفظ
                // ==================================================
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: moxBlue),

                  onPressed: () async {
                    final String newGuardianMoxId = guardianMoxController.text
                        .trim()
                        .toUpperCase();

                    // ------------------------------------------------
                    // تحديث guardianMoxId فقط
                    // ------------------------------------------------

                    user.guardianMoxId = newGuardianMoxId.isEmpty
                        ? null
                        : newGuardianMoxId;

                    // ------------------------------------------------
                    // moxId لا يتم تغييره
                    // ------------------------------------------------

                    Navigator.pop(dialogContext);

                    guardianMoxController.dispose();
                    moxIdController.dispose();

                    // ------------------------------------------------
                    // حفظ UserModel
                    // ------------------------------------------------

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
      // ==========================================================
      // APP BAR
      // ==========================================================
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

      // ==========================================================
      // BODY
      // ==========================================================
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
                    // ------------------------------------------------
                    // الرابط يعتمد فقط على guardianMoxId
                    // ------------------------------------------------

                    final String clientLink = _buildClientStoreLink(user);

                    final bool hasGuardian = _isValidGuardianMoxId(
                      (user.guardianMoxId ?? '').trim().toUpperCase(),
                    );

                    return DataRow(
                      cells: [
                        // ==================================================
                        // الاسم
                        // ==================================================
                        DataCell(
                          Text(user.name.isNotEmpty ? user.name : 'بدون اسم'),
                        ),

                        // ==================================================
                        // الهاتف
                        // ==================================================
                        DataCell(
                          Text(
                            user.phone.isNotEmpty ? user.phone : 'غير متوفر',
                          ),
                        ),

                        // ==================================================
                        // moxId
                        // ==================================================
                        DataCell(
                          Text(user.moxId.isNotEmpty ? user.moxId : '---'),
                        ),

                        // ==================================================
                        // guardianMoxId
                        // ==================================================
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

                        // ==================================================
                        // رابط العميل
                        // ==================================================
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
                                : 'عادي',
                          ),
                        ),

                        // ==================================================
                        // الإجراءات
                        // ==================================================
                        DataCell(
                          Row(
                            children: [
                              // ------------------------------------------
                              // تعديل
                              // ------------------------------------------
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

                              // ------------------------------------------
                              // ترحيل
                              // ------------------------------------------
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
