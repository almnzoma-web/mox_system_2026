import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';

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

  // ============================================================
  // موافقة المستخدم على لائحة إدارة بنك موكس
  // ============================================================

  bool _acceptedMoxRules = false;

  // ============================================================
  // ADMIN REFERRAL ID
  // ============================================================
  //
  // مهم:
  // هذا الرقم يستخدم فقط كإحالة افتراضية.
  //
  // لا يتم تخزينه داخل حساب العميل الجديد.
  // ولا يتم إنشاء علاقة guardian بين العميل والمدير.
  //
  // وظيفته فقط:
  // إذا لم يكتب العميل كود إحالة، يتم اعتبار هذا هو
  // صاحب الإحالة، ويستحق 100 نقطة عند نجاح التسجيل.
  // ============================================================

  static const String _defaultGuardianId = "MOX249-00010001";

  // ============================================================
  // GOOGLE APPS SCRIPT ENDPOINT
  // ============================================================

  static const String _cloudEndpoint =
      'https://script.google.com/macros/s/AKfycbyjUvfKEcii4ck2klEIgPjSXDzss3AipUV6nHpVlqsoJ7gdhefx_Ua8AdHENIbX8HGg/exec';

  // ============================================================
  // PLATFORM CHECK
  // ============================================================

  void _checkPlatformAndRegister() {
    bool isWindowsDevice = false;

    if (defaultTargetPlatform == TargetPlatform.windows) {
      isWindowsDevice = true;
    }

    try {
      if (!kIsWeb && Platform.isWindows) {
        isWindowsDevice = true;
      }
    } catch (_) {}

    if (isWindowsDevice) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "⚠️ تنبيه نظام موكس",
              style: TextStyle(
                color: Color(0xFF28A9CC),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "عذراً، التسجيل عبر نسخة الوندوز محظور تماماً. يُرجى إتمام التسجيل عبر الهاتف المحمول.",
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A9CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "حسناً",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    _register();
  }

  // ============================================================
  // CLOUD SYNC
  // ============================================================
  //
  // ملاحظة أمنية مهمة:
  //
  // guardianMoxIdCustomer يتم إرساله فارغاً دائماً.
  //
  // السبب:
  // رقم الوصي ليس علاقة دائمة بحساب العميل.
  // ============================================================

  Future<void> _syncNewUserToCloud(UserModel user) async {
    final Uri uri = Uri.parse(_cloudEndpoint);

    try {
      await http.post(
        uri,
        body: {
          'action': 'registerUser',
          'moxId': user.moxId,
          'name': user.name,
          'phone': user.phone,
          'password': user.password,
          'address': user.address,
          'gender': user.gender,
          'accountType': user.accountType,

          // ====================================================
          // مهم جداً:
          // لا نحفظ علاقة إحالة داخل العميل الجديد.
          // ====================================================
          'guardianMoxIdCustomer': '',
          'guardianMoxId': '',
          'role': 'user',
          'points': user.points.toString(),
        },
      );

      debugPrint('☁️ [Cloud Sync] تم رفع العميل الجديد بنجاح إلى قوقل.');
    } catch (e) {
      debugPrint(
        '⚠️ [Cloud Sync] تعذر الرفع الفوري لقوقل، '
        'وتم الاكتفاء بالحفظ المحلي: $e',
      );
    }
  }

  // ============================================================
  // GENERATE MOX ID
  // ============================================================

  Future<String> _generateSequentialMoxId() async {
    final Uri uri = Uri.parse(_cloudEndpoint).replace(
      queryParameters: {
        'action': 'getNextMoxId',
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    debugPrint('🆔 [MOX ID] طلب رقم عميل جديد من Google...');

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('كود الخطأ من قوقل: ${response.statusCode}');
      }

      final String body = response.body.trim();

      debugPrint('📥 [MOX ID Raw Response] $body');

      final dynamic decoded = jsonDecode(body);

      if (decoded is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

        final String moxId =
            (data['moxId'] ?? data['id'] ?? data['number'] ?? '')
                .toString()
                .trim()
                .toUpperCase();

        if (moxId.isNotEmpty && !moxId.contains('MOX STORE API')) {
          if (RegExp(r'^\d+$').hasMatch(moxId)) {
            return 'ID-${moxId.padLeft(6, '0')}';
          }

          return moxId;
        }
      }

      // ========================================================
      // FALLBACK
      // ========================================================

      final int nextSeq = 5001 + StorageService.registeredUsers.length;

      final String fallbackId = 'ID-${nextSeq.toString().padLeft(6, '0')}';

      debugPrint('⚠️ [MOX ID Fallback] تم توليد الرقم احتياطياً: $fallbackId');

      return fallbackId;
    } catch (e) {
      debugPrint('🚨 خطأ تفصيلي أثناء جلب الـ ID: $e');

      final int nextSeq = 5001 + StorageService.registeredUsers.length;

      return 'ID-${nextSeq.toString().padLeft(6, '0')}';
    }
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
    if (_isRegistering) {
      return;
    }

    _isRegistering = true;

    try {
      final String phoneInput = _phoneController.text.trim();

      final String password = _passwordController.text.trim();

      final String name = _nameController.text.trim();

      final String address = _addressController.text.trim();

      // ========================================================
      // موافقة اللائحة
      // ========================================================

      if (!_acceptedMoxRules) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ يجب الإقرار بالموافقة على لائحة إدارة بنك موكس والموافقة على موجهات الإدارة قبل إتمام التسجيل.",
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // ========================================================
      // PHONE VALIDATION
      // ========================================================

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

      // ========================================================
      // PASSWORD VALIDATION
      // ========================================================

      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ يرجى إدخال كلمة السر."),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // ========================================================
      // SHOW LOADING
      // ========================================================

      _showLoadingDialog();

      // ========================================================
      // GENERATE MOX ID
      // ========================================================

      final String newMoxId = await _generateSequentialMoxId();

      // ========================================================
      // REFERRAL CODE
      // ========================================================
      //
      // هذا الرقم لا يصبح guardian للعميل.
      //
      // نستخدمه فقط لمعرفة صاحب الإحالة الذي يستحق 100 نقطة.
      // ========================================================

      final String inputGuardian = _guardianController.text.trim();

      final String referralMoxId = inputGuardian.isEmpty
          ? _defaultGuardianId
          : inputGuardian;

      // ========================================================
      // CREATE USER
      // ========================================================
      //
      // أهم نقطة في النسخة الجديدة:
      //
      // role = user
      //
      // guardianMoxId = ''
      //
      // guardianMoxIdCustomer = ''
      //
      // وبالتالي لا يوجد ارتباط وصاية داخل الحساب.
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

        // ======================================================
        // صلاحية العميل
        // ======================================================
        role: "user",

        customWhatsApp: null,

        // ======================================================
        // لا توجد علاقة وصاية محفوظة
        // ======================================================
        guardianMoxId: "",

        guardianMoxIdCustomer: "",

        points: 0,

        myAssets: const [],
      );

      // ========================================================
      // SAVE USER + REFERRAL REWARD
      // ========================================================

      final bool success = await _addUserWithReferral(newUser, referralMoxId);

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
      // تثبيت العميل الجديد كجلسة حالية
      // ========================================================
      //
      // مهم:
      // الجلسة تحمل newUser الذي role فيه = user.
      //
      // لا نضع المدير ولا بيانات المدير هنا.
      // ========================================================

      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('mox_current_user', jsonEncode(newUser.toJson()));

        debugPrint('🔐 [SESSION] تم تثبيت العميل الجديد كمستخدم حالي.');

        debugPrint('👤 [SESSION ROLE] ${newUser.role}');

        debugPrint('🆔 [SESSION MOX] ${newUser.moxId}');
      } catch (e) {
        debugPrint('⚠️ خطأ في تثبيت الجلسة المحلية: $e');
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
    } finally {
      _isRegistering = false;
    }
  }

  // ============================================================
  // ADD USER + REFERRAL
  // ============================================================
  //
  // القاعدة الجديدة:
  //
  // 1. العميل الجديد لا يحصل على guardian.
  //
  // 2. رقم الوصي/الإحالة لا يتم حفظه في العميل.
  //
  // 3. نبحث فقط عن صاحب moxId المطابق.
  //
  // 4. إذا وجدناه:
  //    points = points + 100
  //
  // 5. إذا لم نجده:
  //    العميل يسجل عادي بدون نقاط إحالة.
  //
  // 6. لا يتم تعديل guardianMoxId للعميل الجديد.
  // ============================================================

  Future<bool> _addUserWithReferral(
    UserModel newUser,
    String referralMoxId,
  ) async {
    // ==========================================================
    // 1. تأكد من تحميل Local Cache
    // ==========================================================

    await StorageService.ensureLoaded();

    // ==========================================================
    // 2. Sync أخير قبل التسجيل
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
    // 5. SAVE NEW USER
    // ==========================================================
    //
    // قبل مكافأة الإحالة.
    //
    // العميل الجديد يتم حفظه بدون guardian.
    // ==========================================================

    try {
      await StorageService.addUser(newUser);

      await _syncNewUserToCloud(newUser);
    } catch (e) {
      debugPrint('❌ [Registration] فشل حفظ العميل: $e');

      return false;
    }

    // ==========================================================
    // 6. REFERRAL REWARD ONLY
    // ==========================================================
    //
    // نبحث عن صاحب الرقم نفسه فقط.
    //
    // لا نبحث في guardianMoxId.
    // لا نبحث في guardianMoxIdCustomer.
    //
    // السبب:
    // المطلوب هو:
    //
    // "من يملك رقم MOX الذي أدخله العميل؟"
    //
    // وليس:
    //
    // "من لديه هذا الرقم في حقل وصاية؟"
    // ==========================================================

    final String cleanReferralId = referralMoxId.trim().toUpperCase();

    if (cleanReferralId.isEmpty) {
      debugPrint('ℹ️ [Referral] لا يوجد كود إحالة.');

      return true;
    }

    UserModel? referralOwner;

    try {
      referralOwner = StorageService.registeredUsers.firstWhere(
        (u) => u.moxId.trim().toUpperCase() == cleanReferralId,
      );
    } catch (_) {
      referralOwner = null;
    }

    // ==========================================================
    // 7. IF OWNER FOUND → +100 POINTS
    // ==========================================================

    if (referralOwner != null) {
      final int oldPoints = referralOwner.points;

      final int newPoints = oldPoints + 100;

      final UserModel updatedReferralOwner = referralOwner.copyWith(
        points: newPoints,
      );

      try {
        await StorageService.updateUserPartial(updatedReferralOwner);

        debugPrint(
          '🎁 [Referral] صاحب $cleanReferralId '
          'حصل على 100 نقطة.',
        );

        debugPrint('📊 [Referral] النقاط القديمة: $oldPoints');

        debugPrint('📊 [Referral] النقاط الجديدة: $newPoints');
      } catch (e) {
        debugPrint(
          '⚠️ [Referral] تم تسجيل العميل '
          'لكن فشل تحديث نقاط صاحب الإحالة: $e',
        );
      }
    } else {
      // ========================================================
      // رقم غير موجود
      // ========================================================

      debugPrint(
        'ℹ️ [Referral] لم يتم العثور على صاحب '
        'الكود: $cleanReferralId',
      );

      // العميل يستمر في التسجيل بشكل طبيعي.
      // لا يتم إنشاء علاقة.
      // لا توجد نقاط إحالة.
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
                      backgroundColor: const Color(0xFF28A9CC),
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
            // REFERRAL / GUARDIAN CODE
            // ==================================================
            //
            // ملاحظة:
            // الاسم في الواجهة يمكن أن يبقى "الوصي أو المرشد"
            // لكن وظيفته الحقيقية الآن "كود إحالة".
            //
            // لا يتم إنشاء علاقة guardian.
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
                    "💡 بطاقة الإحالة أو المرشد (اختياري)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF28A9CC),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "إذا أخبرك عميل عن موكس، ضع رقم MOX الخاص به. عند نجاح التسجيل يحصل صاحب الرقم على 100 نقطة. لا يتم إنشاء أي علاقة وصاية بين الحسابين.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _guardianController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "رقم MOX للإحالة",
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
            // MOX RULES AGREEMENT
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
              onPressed: _isRegistering ? null : _checkPlatformAndRegister,
              child: _isRegistering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
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
