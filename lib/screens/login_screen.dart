import 'package:flutter/material.dart';
import '../models/user_model.dart';
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

  @override
  void initState() {
    super.initState();
    // التقاط الرابط الخارجي تلقائياً عند فتح التطبيق والتوجيه لمتجر العميل المعني
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncomingStoreLink();
    });
  }

  // فحص دقيق وخالٍ من الأخطاء لالتقاط رقم هاتف المتجر الخارجي
  void _checkIncomingStoreLink() {
    try {
      final Uri uri = Uri.base;
      if (uri.queryParameters.containsKey('phone') ||
          uri.path.contains('/store')) {
        final String? targetPhone = uri.queryParameters['phone'];
        if (targetPhone != null && targetPhone.isNotEmpty) {
          final UserModel targetClientUser = UserModel(
            phone: targetPhone,
            password: "",
            name: "العميل صاحب المتجر الرقمي",
            moxId: "MOX249-00000001",
            address: "متجر رقمي",
            balance: 0.0,
            gender: "ذكر",
            accountType: "فردي",
          );

          // التوجيه المباشر للداشبورد مع تمرير مؤشر القراءة فقط للمتجر الخارجي
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                user: targetClientUser,
                isReadOnlyStore: true,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // تفادي أي استثناء قد يظهر في بيئة الويب أو الموبايل أثناء قراءة الرابط
    }
  }

  void _validateAndLogin() {
    String input = _inputController.text.trim();

    bool isValid = widget.isMoxIdLogin
        ? RegExp(r'^MOX249-\d{8}$').hasMatch(input)
        : RegExp(r'^249\d{9}$').hasMatch(input);

    if (isValid) {
      final UserModel authenticatedUser = UserModel(
        phone: widget.isMoxIdLogin ? "0000000000" : input,
        password: _passwordController.text.trim(),
        name: "المستخدم السيادي",
        moxId: widget.isMoxIdLogin ? input : "MOX249-00000000",
        address: "الخرطوم",
        balance: 0.0,
        gender: "ذكر",
        accountType: "فردي",
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DashboardScreen(user: authenticatedUser, isReadOnlyStore: false),
        ),
        (route) => false,
      );
    } else {
      _showError(
        widget.isMoxIdLogin
            ? "رقم MOX غير مطابق للمعايير (مثال: MOX249-12345678)"
            : "رقم الهاتف يجب أن يبدأ بـ 249 ويتكون من 12 رقماً",
      );
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
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "كلمة السر",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _validateAndLogin,
                    child: const Text(
                      "دخول المنظومة",
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
