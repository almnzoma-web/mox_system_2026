// ignore_for_file: unnecessary_null_comparison

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

  final TextEditingController _inputController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // ============================================================
  // حفظ تسجيل الدخول
  // ============================================================

  bool _rememberLoginSession = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _validateAndLogin() async {
    final String input = _inputController.text.trim();

    final String password = _passwordController.text.trim();

    // ----------------------------------------------------------
    // التحقق من البيانات
    // ----------------------------------------------------------

    if (input.isEmpty || password.isEmpty) {
      _showError(
        "⚠️ تنبيه: يرجى إدخال البيانات كاملة (المعرف/الهاتف وكلمة السر)",
      );
      return;
    }

    // ----------------------------------------------------------
    // التحقق من الصيغة
    // ----------------------------------------------------------

    final bool isFormatValid = widget.isMoxIdLogin
        ? RegExp(r'^MOX249-\d{8}$').hasMatch(input)
        : RegExp(r'^249\d{9}$').hasMatch(input);

    if (!isFormatValid) {
      _showError(
        widget.isMoxIdLogin
            ? "رقم MOX غير مطابق للمعايير (مثال: MOX249-12345678)"
            : "رقم الهاتف يجب أن يبدأ بـ 249 ويتكون من 12 رقماً",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // المصادقة
      // ========================================================

      UserModel? authenticatedUser = await StorageService.authenticateAsync(
        input,
        password,
        widget.isMoxIdLogin,
      );

      // --------------------------------------------------------
      // فشل تسجيل الدخول
      // --------------------------------------------------------

      if (authenticatedUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError(
          "❌ خطأ أمني: البيانات المدخلة غير مسجلة أو كلمة السر غير صحيحة!",
        );

        return;
      }

      // ========================================================
      // حماية MoxId
      // ========================================================

      if (authenticatedUser.moxId == null ||
          authenticatedUser.moxId.trim().isEmpty) {
        if (widget.isMoxIdLogin) {
          authenticatedUser.moxId = input;
        } else if (authenticatedUser.phone != null &&
            authenticatedUser.phone.isNotEmpty) {
          final String digits = authenticatedUser.phone.replaceAll(
            RegExp(r'\D'),
            '',
          );

          if (digits.length >= 8) {
            authenticatedUser.moxId =
                "MOX249-${digits.substring(digits.length - 8)}";
          } else {
            authenticatedUser.moxId = "ID-005000";
          }
        } else {
          authenticatedUser.moxId = "ID-005001";
        }
      }

      // ========================================================
      // حفظ أو عدم حفظ الجلسة
      // ========================================================
      //
      // ✔️ المربع مفعل:
      //    نحفظ المستخدم في SharedPreferences
      //
      // ⬜ المربع غير مفعل:
      //    نحذف أي جلسة محفوظة سابقاً
      //
      // ========================================================

      if (_rememberLoginSession) {
        await StorageService.saveUser(authenticatedUser);
      } else {
        await StorageService.logout();
      }

      // ========================================================
      // دخول لوحة التحكم
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

      _showError("⚠️ حدث خطأ أثناء الاتصال بالخزينة السيادية: $e");
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
    _inputController.dispose();
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
                  // ------------------------------------------------
                  // INPUT
                  // ------------------------------------------------
                  TextField(
                    controller: _inputController,

                    keyboardType: widget.isMoxIdLogin
                        ? TextInputType.text
                        : TextInputType.phone,

                    decoration: InputDecoration(
                      labelText: widget.isMoxIdLogin
                          ? "رقم موكس"
                          : "رقم الهاتف",

                      prefixIcon: Icon(
                        widget.isMoxIdLogin ? Icons.badge : Icons.phone_android,
                        color: moxBlue,
                      ),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: moxBlue, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // PASSWORD
                  // ------------------------------------------------
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
