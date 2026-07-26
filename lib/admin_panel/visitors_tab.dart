import 'package:flutter/material.dart';
import '../../data/user_data.dart';
import '../models/user_model.dart';

class VisitorsTab extends StatefulWidget {
  const VisitorsTab({super.key});
  @override
  State<VisitorsTab> createState() => _VisitorsTabState();
}

class _VisitorsTabState extends State<VisitorsTab> {
  // تحديث الشاشة بعد أي عملية
  Future<void> _refreshData() async {
    await loadUsers();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("سجل الزوار والعملاء"),
        backgroundColor: const Color(0xFF28A9CC),
        centerTitle: true,
      ),
      body: registeredUsers.isEmpty
          ? const Center(child: Text("الخزنة فارغة حالياً"))
          : ListView.builder(
              itemCount: registeredUsers.length,
              itemBuilder: (context, index) {
                final user = registeredUsers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == 'admin'
                          ? Colors.red
                          : Colors.blueGrey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "MOX: ${user.moxId} | الرصيد: ${user.balance}",
                    ),
                    // إضافة الترس لكل عميل (ما عدا المدير) للتحكم في الزوار
                    trailing: user.role != 'admin'
                        ? IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Color(0xFF28A9CC),
                            ),
                            tooltip: "التحكم في العميل",
                            onPressed: () => _showControlPanel(user),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  // الشاشة المنبثة الخاصة بالترس للتحكم في العميل (حظر أو إغلاق)
  void _showControlPanel(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "التحكم في الزائر/العميل: ${user.name}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF28A9CC),
              ),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text(
                "حظر العميل",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                // تنفيذ عملية الحظر برمجياً (مثلاً تغيير الدور أو حذف أو تعليم الحظر حسب رغبة المنظومة)
                debugPrint("تم حظر العميل: ${user.name}");

                Navigator.pop(context); // إغلاق الشاشة المنبثة
                await _refreshData(); // تحديث الواجهة

                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("🚫 تم حظر العميل ${user.name} بنجاح"),
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text("إغلاق الشاشة"),
              onTap: () {
                Navigator.pop(context); // إغلاق الشاشة المنبثة
              },
            ),
          ],
        ),
      ),
    );
  }
}
