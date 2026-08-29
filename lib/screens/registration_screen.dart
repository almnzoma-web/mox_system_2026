import 'dart:convert';

import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:mox_digital_app/main.dart';

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

  // ============================================================
  // ADMIN REFERRAL ID
  // ============================================================

  static const String _defaultGuardianId = "MOX249-00010001";

  // ============================================================
  // GENERATE MOX ID
  // ============================================================
  //
  // moxId يتم توليده من شاشة التسجيل.
  //
  // المدير:
  // ID-005000
  //
  // أول عميل:
  // ID-005001
  //
  // ============================================================

  Future<String> _generateSequentialMoxId() async {
    // ============================================================
    // 0. الحجز الذري المركزي من السحابة (منع سباق الأجهزة المتعددة)
    // ============================================================

    try {
      final Uri cloudApiUri = Uri.parse(
        publicStoreApi,
      ).replace(queryParameters: {'action': 'getNextMoxId'});

      final http.Response cloudResponse = await http
          .get(cloudApiUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (cloudResponse.statusCode == 200) {
        final dynamic decodedCloudJson = jsonDecode(cloudResponse.body);
        if (decodedCloudJson is Map && decodedCloudJson['success'] == true) {
          final String cloudReservedId =
              decodedCloudJson['moxId']?.toString().trim().toUpperCase() ?? '';

          if (RegExp(r'^ID-\d{6}$').hasMatch(cloudReservedId)) {
            debugPrint(
              '🆔 [CLOUD ATOMIC ID] تم حجز الرقم مركزياً بنجاح: $cloudReservedId',
            );
            return cloudReservedId;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ [CLOUD ATOMIC ID EXCEPTION] تعذر الاتصال بالسحابة للحجز الذري، الانتقال للنظام المحلي: $e',
      );
    }

    // ============================================================
    // 1. تأكد أن الذاكرة المحلية محملة
    // ============================================================

    await StorageService.ensureLoaded();

    // ============================================================
    // 2. حاول تحديث العملاء من السحابة
    //
    // مهم:
    // لا نستخدم loadUsers() هنا لأنها تعيد بناء registeredUsers
    // من Local Storage فقط.
    //
    // syncClientsFromCloud() تعمل Merge:
    //
    // Local + Cloud
    //
    // ولا تستبدل المحلي بالسحابة.
    // ============================================================

    try {
      final bool synced = await StorageService.syncClientsFromCloud(
        saveLocal: true,
      );

      debugPrint(
        synced
            ? '☁️ [MOX ID] تم تحديث العملاء من السحابة قبل توليد الرقم.'
            : '⚠️ [MOX ID] تعذر تحديث السحابة، سيتم الاعتماد على البيانات المحلية.',
      );
    } catch (e) {
      debugPrint('⚠️ [MOX ID] Cloud Sync Exception: $e');
    }

    // ============================================================
    // 3. جمع كل أرقام MOX الموجودة
    // ============================================================

    final Set<int> existingNumbers = <int>{};

    for (final UserModel user in StorageService.registeredUsers) {
      final String id = user.moxId.trim().toUpperCase();

      if (!id.startsWith('ID-')) {
        continue;
      }

      final String numericPart = id.substring(3).trim();

      final int? number = int.tryParse(numericPart);

      if (number != null && number >= 5000) {
        existingNumbers.add(number);
      }
    }

    // ============================================================
    // 4. نبدأ بعد ID المدير
    //
    // المدير = ID-005000
    // أول عميل = ID-005001
    // ============================================================

    int nextNumber = 5001;

    // ============================================================
    // 5. ابحث عن أعلى رقم موجود
    // ============================================================

    if (existingNumbers.isNotEmpty) {
      nextNumber = existingNumbers.reduce((int a, int b) => a > b ? a : b) + 1;
    }

    // ============================================================
    // 6. حماية إضافية
    //
    // حتى لو حدثت مشكلة في ترتيب البيانات، لا نعيد أبداً
    // رقم مستخدم موجود.
    // ============================================================

    while (existingNumbers.contains(nextNumber)) {
      nextNumber++;
    }

    // ============================================================
    // 7. تكوين MOX ID
    // ============================================================

    final String formattedNumber = nextNumber.toString().padLeft(6, '0');

    final String newMoxId = 'ID-$formattedNumber';

    debugPrint(
      '🆔 [MOX ID] '
      'Existing IDs: ${existingNumbers.length} '
      '| Generated: $newMoxId',
    );

    return newMoxId;
  }
  // ============================================================
  // LOADING
  // ============================================================

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    final phoneInput = _phoneController.text.trim();

    final password = _passwordController.text.trim();

    final name = _nameController.text.trim();

    final address = _addressController.text.trim();

    // ==========================================================
    // PHONE VALIDATION
    // ==========================================================

    final bool isPhoneValid = RegExp(r'^249\d{9}$').hasMatch(phoneInput);

    if (name.isEmpty || !isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ يرجى إدخال الاسم كاملاً، ورقم الهاتف بالصيغة الصحيحة (249xxxxxxxxx).",
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ يرجى إدخال كلمة السر."),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ==========================================================
    // SHOW LOADING
    // ==========================================================

    _showLoadingDialog();

    try {
      // ========================================================
      // GENERATE MOX ID
      // ========================================================

      final String newMoxId = await _generateSequentialMoxId();

      // ========================================================
      // GUARDIAN
      // ========================================================

      final inputGuardian = _guardianController.text.trim();

      final String finalCustomerGuardianId = inputGuardian.isEmpty
          ? _defaultGuardianId
          : inputGuardian;

      // ========================================================
      // CREATE USER
      // ========================================================

      final newUser = UserModel(
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
      // SAVE USER + REFERRAL
      // ========================================================

      final bool success = await _addUserWithReferral(
        newUser,
        finalCustomerGuardianId,
      );

      if (!success) {
        if (mounted) {
          Navigator.pop(context);

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

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      // ========================================================
      // CERTIFICATE
      // ========================================================

      _showSovereignCertificate(newUser, newMoxId);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ حدث خطأ أثناء التسجيل: $e"),
            backgroundColor: Colors.red,
          ),
        );
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
    // ============================================================
    // 1. تأكد من تحميل Local Cache
    // ============================================================

    await StorageService.ensureLoaded();

    // ============================================================
    // 2. Sync أخير قبل التسجيل
    //
    // هذا مهم جداً لمنع استخدام رقم قد يكون أُضيف من جهاز آخر
    // أثناء بقاء هذه الشاشة مفتوحة.
    // ============================================================

    try {
      await StorageService.syncClientsFromCloud(saveLocal: true);
    } catch (e) {
      debugPrint('⚠️ [Registration] تعذر تحديث السحابة قبل التسجيل: $e');
    }

    // ============================================================
    // 3. CHECK DUPLICATE PHONE
    // ============================================================

    final String newPhone = newUser.phone.trim();

    final bool phoneExists = StorageService.registeredUsers.any(
      (u) => u.phone.trim() == newPhone,
    );

    if (phoneExists) {
      debugPrint('❌ [Registration] رقم الهاتف موجود مسبقاً: $newPhone');

      return false;
    }

    // ============================================================
    // 4. CHECK DUPLICATE MOX ID
    // ============================================================

    final String newMoxId = newUser.moxId.trim().toUpperCase();

    final bool moxIdExists = StorageService.registeredUsers.any(
      (u) => u.moxId.trim().toUpperCase() == newMoxId,
    );

    if (moxIdExists) {
      debugPrint('❌ [Registration] Mox ID موجود مسبقاً: $newMoxId');

      return false;
    }

    // ============================================================
    // 5. FIND GUARDIAN
    // ============================================================

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

    // ============================================================
    // 6. SAVE NEW USER
    // ============================================================

    try {
      await StorageService.addUser(newUser);
    } catch (e) {
      debugPrint('❌ [Registration] فشل حفظ العميل: $e');

      return false;
    }

    // ============================================================
    // 7. UPDATE GUARDIAN POINTS
    // ============================================================

    if (guardian != null) {
      final UserModel updatedGuardian = guardian.copyWith(
        points: guardian.points + 100,
      );

      try {
        await StorageService.updateUserPartial(updatedGuardian);

        debugPrint('🎁 [Registration] تم منح الوصي 100 نقطة.');
      } catch (e) {
        debugPrint(
          '⚠️ [Registration] تم تسجيل العميل '
          'لكن فشل تحديث نقاط الوصي: $e',
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "شهادة اعتماد",
      pageBuilder: (context, animation, secondaryAnimation) {
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
                      backgroundColor: Color(0xFF28A9CC),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);

                      Navigator.pop(context);
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

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 15),

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

            const SizedBox(height: 30),

            // ==================================================
            // REGISTER BUTTON
            // ==================================================
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: moxBlue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _register,
              child: const Text(
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
