import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../services/storage_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final Color moxBlue = const Color(0xFF28A9CC);

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _guardianController = TextEditingController();

  String _selectedGender = "ذكر";

  String _selectedAccountType = "فردي";

  bool _isPasswordVisible = false;

  bool _isRegistering = false;

  bool _acceptedMoxRules = false;

  // ============================================================
  // DEFAULT GUARDIAN
  // ============================================================

  static const String _defaultGuardianId = "MOX249-00010001";

  // ============================================================
  // LOADING STATE
  // ============================================================

  bool _loadingDialogVisible = false;

  // ============================================================
  // GENERATE CENTRAL MOX ID
  // ============================================================

  Future<String> _generateSequentialMoxId() async {
    final Uri uri =
        Uri.parse(
          'https://script.google.com/macros/s/AKfycbyjUvfKEcii4ck2klEIgPjSXDzss3AipUV6nHpVlqsoJ7gdhefx_Ua8AdHENIbX8HGg/exec',
        ).replace(
          queryParameters: {
            'action': 'getNextMoxId',
            't': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

    debugPrint('🆔 [MOX ID] طلب رقم مركزي جديد من Google...');

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('كود الخطأ من Google: ${response.statusCode}');
    }

    final String body = response.body.trim();

    debugPrint('📥 [MOX ID Raw Response] $body');

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (e) {
      throw Exception('استجابة Google ليست JSON صحيحة: $body');
    }

    if (decoded is! Map) {
      throw Exception('استجابة Google غير صحيحة.');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    final bool success =
        data['success'] == true ||
        data['status'].toString().toLowerCase() == 'success';

    if (!success) {
      throw Exception(
        data['message']?.toString() ?? 'تعذر الحصول على رقم MOX مركزي.',
      );
    }

    String moxId = (data['moxId'] ?? data['id'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (moxId.isEmpty) {
      throw Exception('Google لم يرجع رقم MOX.');
    }

    // ==========================================================
    // NORMALIZE NUMERIC RESPONSE
    // ==========================================================

    if (RegExp(r'^\d+$').hasMatch(moxId)) {
      moxId = 'ID-${moxId.padLeft(6, '0')}';
    }

    // ==========================================================
    // VALIDATE FORMAT
    // ==========================================================

    if (!RegExp(r'^ID-\d{6}$').hasMatch(moxId)) {
      throw Exception('رقم MOX غير صالح: $moxId');
    }

    debugPrint('✅ [MOX ID] تم استلام الرقم المركزي: $moxId');

    return moxId;
  }

  // ============================================================
  // SHOW LOADING
  // ============================================================

  void _showLoadingDialog() {
    if (!mounted || _loadingDialogVisible) {
      return;
    }

    _loadingDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: moxBlue),

                const SizedBox(width: 20),

                const Expanded(
                  child: Text(
                    "جاري اعتمادك في بنك موكس...",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _loadingDialogVisible = false;
    });
  }

  // ============================================================
  // CLOSE LOADING SAFELY
  // ============================================================

  void _closeLoadingDialog() {
    if (!mounted || !_loadingDialogVisible) {
      return;
    }

    _loadingDialogVisible = false;

    Navigator.of(context).pop();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    // ==========================================================
    // PROTECT DOUBLE CLICK
    // ==========================================================

    if (_isRegistering) {
      debugPrint('⚠️ [Registration] التسجيل قيد التنفيذ بالفعل.');
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final String phoneInput = _phoneController.text.trim();

      final String password = _passwordController.text.trim();

      final String name = _nameController.text.trim();

      final String address = _addressController.text.trim();

      // ========================================================
      // RULES
      // ========================================================

      if (!_acceptedMoxRules) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ يجب الإقرار بالموافقة على لائحة إدارة بنك موكس والموافقة على موجهات الإدارة قبل إتمام التسجيل.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }

        return;
      }

      // ========================================================
      // PHONE
      // ========================================================

      final bool isPhoneValid = RegExp(r'^249\d{9}$').hasMatch(phoneInput);

      if (name.isEmpty || !isPhoneValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ يرجى إدخال الاسم كاملاً، ورقم الهاتف بالصيغة الصحيحة (249xxxxxxxxx).",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }

        return;
      }

      // ========================================================
      // PASSWORD
      // ========================================================

      if (password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ يرجى إدخال كلمة السر."),
              backgroundColor: Colors.red,
            ),
          );
        }

        return;
      }

      // ========================================================
      // SHOW LOADING
      // ========================================================

      _showLoadingDialog();

      // ========================================================
      // GET CENTRAL MOX ID
      // ========================================================

      final String newMoxId = await _generateSequentialMoxId();

      debugPrint('🆔 [Registration] MOX ID المحجوز: $newMoxId');

      // ========================================================
      // GUARDIAN
      // ========================================================

      final String inputGuardian = _guardianController.text.trim();

      final String finalCustomerGuardianId = inputGuardian.isEmpty
          ? _defaultGuardianId
          : inputGuardian;

      // ========================================================
      // CREATE USER
      // ========================================================

      final UserModel newUser = UserModel(
        phone: phoneInput,

        password: password,

        name: name,

        moxId: newMoxId,

        address: address,

        balance: 0.0,

        commission: 0.0,

        gender: _selectedGender,

        accountType: _selectedAccountType,

        role: "user",

        customWhatsApp: null,

        guardianMoxId: "",

        guardianMoxIdCustomer: finalCustomerGuardianId,

        points: 0,

        myAssets: const [],
      );

      // ========================================================
      // SAVE USER
      // ========================================================

      final bool success = await _addUserWithReferral(
        newUser,
        finalCustomerGuardianId,
      );

      // ========================================================
      // SAVE FAILED
      // ========================================================

      if (!success) {
        _closeLoadingDialog();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ تعذر اعتماد الحساب في قاعدة البيانات السحابية."),
              backgroundColor: Colors.red,
            ),
          );
        }

        return;
      }

      // ========================================================
      // CLOSE LOADING
      // ========================================================

      _closeLoadingDialog();

      // ========================================================
      // SHOW CERTIFICATE
      // ========================================================

      if (!mounted) {
        return;
      }

      _showSovereignCertificate(newUser, newMoxId);
    } catch (e) {
      // ========================================================
      // CLOSE LOADING IF OPEN
      // ========================================================

      _closeLoadingDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ حدث خطأ أثناء التسجيل: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }

      debugPrint('🚨 [Registration Error] $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  // ============================================================
  // ADD USER + REFERRAL
  // ============================================================

  Future<bool> _addUserWithReferral(
    UserModel newUser,
    String guardianId,
  ) async {
    // ==========================================================
    // 1. LOAD LOCAL CACHE
    // ==========================================================

    await StorageService.ensureLoaded();

    // ==========================================================
    // 2. SYNC CLOUD
    // ==========================================================

    try {
      await StorageService.syncClientsFromCloud(saveLocal: true);
    } catch (e) {
      debugPrint('⚠️ [Registration] تعذر تحديث السحابة قبل التسجيل: $e');
    }

    // ==========================================================
    // 3. CHECK DUPLICATE PHONE
    // ==========================================================

    final String newPhone = newUser.phone.trim();

    final bool phoneExists = StorageService.registeredUsers.any(
      (u) => u.phone.trim() == newPhone,
    );

    if (phoneExists) {
      debugPrint('❌ [Registration] رقم الهاتف موجود مسبقاً: $newPhone');

      return false;
    }

    // ==========================================================
    // 4. CHECK DUPLICATE MOX ID
    // ==========================================================

    final String newMoxId = newUser.moxId.trim().toUpperCase();

    final bool moxIdExists = StorageService.registeredUsers.any(
      (u) => u.moxId.trim().toUpperCase() == newMoxId,
    );

    if (moxIdExists) {
      debugPrint('❌ [Registration] Mox ID موجود مسبقاً: $newMoxId');

      return false;
    }

    // ==========================================================
    // 5. FIND GUARDIAN
    // ==========================================================

    UserModel? guardian;

    final String cleanGuardianId = guardianId.trim().toUpperCase();

    if (cleanGuardianId.isNotEmpty) {
      try {
        guardian = StorageService.registeredUsers.firstWhere((u) {
          final String moxId = u.moxId.trim().toUpperCase();

          final String guardianMoxId = (u.guardianMoxId ?? '')
              .trim()
              .toUpperCase();

          final String guardianMoxIdCustomer = (u.guardianMoxIdCustomer ?? '')
              .trim()
              .toUpperCase();

          return moxId == cleanGuardianId ||
              guardianMoxId == cleanGuardianId ||
              guardianMoxIdCustomer == cleanGuardianId;
        });
      } catch (_) {
        guardian = null;
      }
    }

    // ==========================================================
    // 6. SAVE NEW USER
    // ==========================================================

    try {
      await StorageService.addUser(newUser);
    } catch (e) {
      debugPrint('❌ [Registration] فشل حفظ العميل: $e');

      return false;
    }

    // ==========================================================
    // 7. UPDATE GUARDIAN
    // ==========================================================

    if (guardian != null) {
      final UserModel updatedGuardian = guardian.copyWith(
        points: guardian.points + 100,
      );

      try {
        await StorageService.updateUserPartial(updatedGuardian);

        debugPrint('🎁 [Registration] تم منح الوصي 100 نقطة.');
      } catch (e) {
        debugPrint(
          '⚠️ [Registration] تم تسجيل العميل لكن فشل تحديث نقاط الوصي: $e',
        );
      }
    } else {
      debugPrint('ℹ️ [Registration] لم يتم العثور على الوصي: $guardianId');
    }

    return true;
  }

  // ============================================================
  // CERTIFICATE
  // ============================================================

  void _showSovereignCertificate(UserModel registeredUser, String moxId) {
    if (!mounted) {
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "شهادة اعتماد",

      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),

          child: Container(
            constraints: const BoxConstraints(maxHeight: 550),

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: moxBlue, width: 3),
            ),

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.verified_user,
                    color: Color(0xFF28A9CC),
                    size: 70,
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "شهادة اعتماد سيادية",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28A9CC),
                    ),
                  ),

                  const Divider(
                    thickness: 2,
                    color: Colors.black12,
                    height: 25,
                  ),

                  const Text(
                    "تم اعتمادك في بنك موكس الرقمي بنجاح.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: Text(
                      "كود الهوية الرقمية:\n$moxId",

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "هذا الكود هو مفتاح حسابك الرقمي في منظومة MOX.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 25),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A9CC),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    // ==================================================
                    // IMPORTANT:
                    // POP THE CERTIFICATE ONLY ONCE
                    // ==================================================
                    onPressed: () {
                      if (!mounted) {
                        return;
                      }

                      Navigator.of(dialogContext).pop();
                    },

                    child: const Text(
                      "استمرار",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();

    _phoneController.dispose();

    _passwordController.dispose();

    _addressController.dispose();

    _guardianController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          "تسجيل عميل سيادي",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: moxBlue,

        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),

        child: Column(
          children: [
            const Icon(
              Icons.account_circle,
              size: 80,
              color: Color(0xFF28A9CC),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // NAME
            // ==================================================
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // PHONE
            // ==================================================
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
                hintText: "249xxxxxxxxx",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // PASSWORD
            // ==================================================
            TextField(
              controller: _passwordController,

              obscureText: !_isPasswordVisible,

              decoration: InputDecoration(
                labelText: "كلمة السر",

                border: const OutlineInputBorder(),

                prefixIcon: const Icon(Icons.lock),

                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),

                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // ADDRESS
            // ==================================================
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "العنوان",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // GUARDIAN
            // ==================================================
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moxBlue.withValues(alpha: 0.4)),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    "💡 بطاقة الوصي أو المرشد (اختياري)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF28A9CC),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "إذا أخبرك عميل عن موكس، ضع رقم MOX الخاص به. وإذا تركته فارغاً، سيُسجل المدير كمرشد افتراضي.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _guardianController,

                    decoration: const InputDecoration(
                      labelText: "رقم MOX للوصي",
                      hintText: "MOX249-00010001",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.supervised_user_circle,
                        color: Color(0xFF28A9CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // GENDER
            // ==================================================
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,

              items: [
                "ذكر",
                "أنثى",
              ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),

              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedGender = v);
                }
              },

              decoration: const InputDecoration(
                labelText: "الجنس",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // ACCOUNT TYPE
            // ==================================================
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountType,

              items: [
                "فردي",
                "تجاري",
              ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),

              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedAccountType = v);
                }
              },

              decoration: const InputDecoration(
                labelText: "نوع الحساب",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // MOX RULES
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

              decoration: BoxDecoration(
                color: Colors.grey[50],

                borderRadius: BorderRadius.circular(10),

                border: Border.all(
                  color: _acceptedMoxRules
                      ? moxBlue.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.35),
                ),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  SizedBox(
                    width: 28,
                    height: 28,

                    child: Checkbox(
                      value: _acceptedMoxRules,

                      activeColor: moxBlue,

                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

                      visualDensity: VisualDensity.compact,

                      onChanged: (bool? value) {
                        setState(() {
                          _acceptedMoxRules = value ?? false;
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Expanded(
                    child: Text(
                      "أقر بموافقتي على لائحة إدارة بنك موكس للتطبيق والالتزام بموجهات الإدارة",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // REGISTER BUTTON
            // ==================================================
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: moxBlue,

                minimumSize: const Size(double.infinity, 50),
              ),

              onPressed: _isRegistering ? null : _register,

              child: _isRegistering
                  ? const SizedBox(
                      width: 24,
                      height: 24,

                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "إتمام التسجيل السيادي",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const SizedBox(height: 40),

            Text(
              "جميع الحقوق محفوظة ©️ المنظومة أونلاين موكس ${DateTime.now().year}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
