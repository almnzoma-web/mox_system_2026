import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isMoxIdLogin;

  const LoginScreen({super.key, required this.isMoxIdLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color moxBlue = const Color(0xFF28A9CC);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _guardianMoxIdController =
      TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isPasswordVisible = false;

  bool _isLoading = false;

  bool _rememberLoginSession = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _validateAndLogin() async {
    final String phone = _phoneController.text.trim();

    final String guardianMoxId = _guardianMoxIdController.text.trim();

    final String password = _passwordController.text.trim();

    // ==========================================================
    // 1. تحديد هل البيانات تخص المدير
    //
    // مهم:
    // منطق المدير يبقى كما هو.
    //
    // المدير يستطيع الدخول بهويته الحالية.
    // ==========================================================

    final bool isAdminPhone = phone == StorageService.adminUser.phone;

    final bool isAdminGuardian =
        guardianMoxId.toUpperCase() ==
        (StorageService.adminUser.guardianMoxId ?? '').toUpperCase();

    final bool isAdmin = isAdminPhone || isAdminGuardian;

    // ==========================================================
    // 2. المدير
    //
    // لا نفرض عليه وجود الهاتف والـ guardian معاً.
    // ==========================================================

    if (isAdmin) {
      if (password.isEmpty) {
        _showError("⚠️ يرجى إدخال كلمة السر.");
        return;
      }

      if (!isAdminPhone && !isAdminGuardian) {
        _showError("❌ بيانات المدير غير صحيحة.");
        return;
      }

      await _loginAdmin(
        phone: phone,
        guardianMoxId: guardianMoxId,
        password: password,
      );

      return;
    }

    // ==========================================================
    // 3. العملاء
    //
    // العميل يجب أن يدخل:
    //
    // الهاتف + guardianMoxId + كلمة السر
    //
    // الثلاثة معاً.
    // ==========================================================

    if (phone.isEmpty || guardianMoxId.isEmpty || password.isEmpty) {
      _showError("⚠️ يرجى إدخال رقم الهاتف و guardianMoxId وكلمة السر كاملة.");
      return;
    }

    // ==========================================================
    // 4. التحقق من الهاتف
    // ==========================================================

    final bool isPhoneValid = RegExp(r'^249\d{9}$').hasMatch(phone);

    if (!isPhoneValid) {
      _showError("⚠️ رقم الهاتف يجب أن يبدأ بـ 249 ويتكون من 12 رقماً.");
      return;
    }

    // ==========================================================
    // 5. التحقق من guardianMoxId
    // ==========================================================

    final bool isGuardianValid = RegExp(
      r'^MOX249-\d{8}$',
    ).hasMatch(guardianMoxId.toUpperCase());

    if (!isGuardianValid) {
      _showError(
        "⚠️ guardianMoxId غير مطابق للمعايير.\n"
        "مثال: MOX249-12345678",
      );
      return;
    }

    // ==========================================================
    // 6. بدء التحميل
    // ==========================================================

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // المصادقة الجديدة للعملاء
      //
      // الهاتف + guardianMoxId + كلمة السر
      // ========================================================

      final UserModel? authenticatedUser =
          await StorageService.authenticateCustomerAsync(
            phone: phone,
            guardianMoxId: guardianMoxId,
            password: password,
          );

      // ========================================================
      // فشل المصادقة
      // ========================================================

      if (authenticatedUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError(
          "❌ خطأ أمني:\n"
          "رقم الهاتف أو guardianMoxId أو كلمة السر غير صحيحة.",
        );

        return;
      }

      // ========================================================
      // حماية إضافية
      //
      // نتأكد أن الحساب الذي عاد من السيرفر هو نفس الحساب
      // المطلوب تسجيل دخوله.
      // ========================================================

      final bool phoneMatches = authenticatedUser.phone.trim() == phone;

      final bool guardianMatches =
          (authenticatedUser.guardianMoxId ?? '').trim().toUpperCase() ==
              guardianMoxId.toUpperCase() ||
          (authenticatedUser.guardianMoxIdCustomer ?? '')
                  .trim()
                  .toUpperCase() ==
              guardianMoxId.toUpperCase();

      if (!phoneMatches || !guardianMatches) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError("❌ رفض أمني: بيانات الهوية لا تتطابق مع سجل العميل.");

        return;
      }

      // ========================================================
      // حفظ الجلسة
      // ========================================================

      if (_rememberLoginSession) {
        await StorageService.saveUser(authenticatedUser);
      } else {
        await StorageService.logout();
      }

      // ========================================================
      // فتح لوحة التحكم
      // ========================================================

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(user: authenticatedUser),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showError("⚠️ حدث خطأ أثناء الاتصال بالخزينة السيادية:\n$e");
    }
  }

  // ============================================================
  // ADMIN LOGIN
  //
  // نحافظ على منطق المدير منفصلاً.
  // ============================================================

  Future<void> _loginAdmin({
    required String phone,
    required String guardianMoxId,
    required String password,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String adminInput = '';

      bool isMoxId = false;

      // --------------------------------------------------------
      // إذا أُدخل guardianMoxId للمدير
      // --------------------------------------------------------

      if (guardianMoxId.isNotEmpty &&
          guardianMoxId.toUpperCase() ==
              (StorageService.adminUser.guardianMoxId ?? '').toUpperCase()) {
        adminInput = guardianMoxId;

        isMoxId = true;
      }
      // --------------------------------------------------------
      // وإلا استخدم الهاتف
      // --------------------------------------------------------
      else if (phone.isNotEmpty && phone == StorageService.adminUser.phone) {
        adminInput = phone;

        isMoxId = false;
      }

      if (adminInput.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError("❌ بيانات المدير غير صحيحة.");

        return;
      }

      // ========================================================
      // المصادقة القديمة للمدير
      //
      // لا نغيّر طريقة المدير.
      // ========================================================

      final UserModel? authenticatedAdmin =
          await StorageService.authenticateAsync(adminInput, password, isMoxId);

      if (authenticatedAdmin == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError("❌ كلمة السر أو بيانات المدير غير صحيحة.");

        return;
      }

      // ========================================================
      // حفظ الجلسة
      // ========================================================

      if (_rememberLoginSession) {
        await StorageService.saveUser(authenticatedAdmin);
      } else {
        await StorageService.logout();
      }

      // ========================================================
      // فتح لوحة المدير
      // ========================================================

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(user: authenticatedAdmin),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showError("⚠️ حدث خطأ أثناء دخول المدير:\n$e");
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[900],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _phoneController.dispose();

    _guardianMoxIdController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [
          // ======================================================
          // HEADER
          // ======================================================
          Container(
            height: MediaQuery.of(context).size.height * 0.35,

            decoration: BoxDecoration(
              color: moxBlue,

              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),

            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(Icons.shield_moon, size: 80, color: Colors.white),

                  SizedBox(height: 10),

                  Text(
                    "بوابة الدخول السيادية",

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // FORM
          // ======================================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),

              child: Column(
                children: [
                  // =================================================
                  // PHONE
                  // =================================================
                  TextField(
                    controller: _phoneController,

                    keyboardType: TextInputType.phone,

                    decoration: InputDecoration(
                      labelText: "رقم الهاتف",

                      prefixIcon: Icon(Icons.phone_android, color: moxBlue),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: moxBlue, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // GUARDIAN MOX ID
                  // =================================================
                  TextField(
                    controller: _guardianMoxIdController,

                    keyboardType: TextInputType.text,

                    textCapitalization: TextCapitalization.characters,

                    decoration: InputDecoration(
                      labelText: "guardianMoxId",

                      hintText: "مثال: MOX249-12345678",

                      prefixIcon: Icon(Icons.badge, color: moxBlue),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: moxBlue, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // PASSWORD
                  // =================================================
                  TextField(
                    controller: _passwordController,

                    obscureText: !_isPasswordVisible,

                    decoration: InputDecoration(
                      labelText: "كلمة السر",

                      prefixIcon: Icon(Icons.lock, color: moxBlue),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: moxBlue, width: 2),
                      ),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,

                          color: moxBlue,
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

                  // =================================================
                  // REMEMBER LOGIN
                  // =================================================
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberLoginSession,

                        activeColor: moxBlue,

                        onChanged: (bool? value) {
                          setState(() {
                            _rememberLoginSession = value ?? false;
                          });
                        },
                      ),

                      const Text(
                        "هل ترغب في حفظ تسجيل الدخول",

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // LOGIN BUTTON
                  // =================================================
                  _isLoading
                      ? CircularProgressIndicator(color: moxBlue)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: moxBlue,

                            minimumSize: const Size(double.infinity, 50),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          onPressed: _validateAndLogin,

                          child: const Text(
                            "دخول بنك موكس الرقمي",

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                  const Spacer(),

                  // =================================================
                  // FOOTER
                  // =================================================
                  Text(
                    "جميع الحقوق محفوظة ©️ المنظومة أونلاين موكس ${DateTime.now().year}",

                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
