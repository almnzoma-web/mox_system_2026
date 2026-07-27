import 'package:flutter/material.dart';

class AdminCustomerScreen extends StatefulWidget {
  const AdminCustomerScreen({super.key});

  @override
  State<AdminCustomerScreen> createState() => _AdminCustomerScreenState();
}

class _AdminCustomerScreenState extends State<AdminCustomerScreen> {
  final Color moxBlue = const Color(0xFF28A9CC);

  // مثال لعملية غير متزامنة محمية بصمام الأمان
  Future<void> _performSecureAction() async {
    await Future.delayed(const Duration(seconds: 1));

    // الحسم: فحص صمام الأمان لمنع الخطأ (Use build context synchronously)
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تنفيذ العملية بأمان في المنظومة")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "لوحة تحكم العملاء",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: moxBlue,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 100,
              color: Color(0xFF28A9CC),
            ),
            const SizedBox(height: 20),
            const Text(
              "تحكم العملاء السيادي",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // الحسم: الأقواس هنا تنهي تنبيه (curly_braces_in_flow_control_structures)
                if (true) {
                  _performSecureAction();
                }
              },
              child: const Text("اختبار أمان المنظومة"),
            ),
          ],
        ),
      ),
    );
  }
}
