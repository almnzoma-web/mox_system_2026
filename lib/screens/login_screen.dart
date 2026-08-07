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
  bool _rememberLoginSession = false; // ✋ مربع حفظ تسجيل الدخول بالمسطرة

  Future<void> _validateAndLogin() async {
    String input = _inputController.text.trim();
    String password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showError(
        "⚠️ تنبيه: يرجى إدخال البيانات كاملة (المعرف/الهاتف وكلمة السر)",
      );
      return;
    }

    // 1. التحقق من صحة الصيغة بالمسطرة (RegExp)
    bool isFormatValid = widget.isMoxIdLogin
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
      // الاعتماد على دالة التحقق الهجينة التي تتأكد من السجل المحلي والشيت معاً بالمسطرة
      UserModel? authenticatedUser = await StorageService.authenticateAsync(
        input,
        password,
        widget.isMoxIdLogin,
      );

      // 2. التحقق من وجود المستخدم وسلامة كلمة السر
      if (authenticatedUser == null) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          "❌ خطأ أمني: البيانات المدخلة غير مسجلة أو كلمة السر غير صحيحة!",
        );
        return;
      }

      // 🛡️ معالجة حاسمة لمنع نزول moxId خالياً:
      // إذا كان الـ moxId فارغاً في الكائن المسترجع، نقوم بتعبئته تلقائياً بالمعرف المدخل أو توليده بالمسطرة
      if (authenticatedUser.moxId == null ||
          authenticatedUser.moxId.trim().isEmpty) {
        if (widget.isMoxIdLogin) {
          authenticatedUser.moxId = input;
        } else if (authenticatedUser.phone != null &&
            authenticatedUser.phone.isNotEmpty) {
          // توليد معرف موكس قياسي استناداً لرقم الهاتف إذا لم يكن متوفراً
          String digits = authenticatedUser.phone.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 8) {
            authenticatedUser.moxId =
                "MOX249-${digits.substring(digits.length - 8)}";
          } else {
            authenticatedUser.moxId = "MOX249-00000000";
          }
        } else {
          authenticatedUser.moxId = "MOX249-12345678";
        }
      }

      // حفظ الجلسة النشطة الحالية للمستخدم مع اعتماد حالة حفظ تسجيل الدخول
      await StorageService.saveUser(authenticatedUser);

      // 3. نجاح التحقق بالكامل والعبور للوحة التحكم السيادية
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            // ignore: unnecessary_non_null_assertion
            builder: (context) => DashboardScreen(user: authenticatedUser!),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError("⚠️ حدث خطأ أثناء الاتصال بالخزينة السيادية: $e");
    }
  }

  void _showError(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
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
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // ✋ مربع حفظ تسجيل الدخول المضاف بالمسطرة والنص الاحترافي
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
                  // التوقيع السيادي
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
