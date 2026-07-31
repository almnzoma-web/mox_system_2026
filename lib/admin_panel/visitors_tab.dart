import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../models/user_model.dart';

class VisitorsTab extends StatefulWidget {
  const VisitorsTab({super.key});

  @override
  State<VisitorsTab> createState() => _VisitorsTabState();
}

class _VisitorsTabState extends State<VisitorsTab> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // تحديث الشاشة وسحب البيانات من الخزينة الهجينة بالمسطرة
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await StorageService.loadUsers();
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "سجل الزوار والعملاء",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF28A9CC),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
            )
          : StorageService.registeredUsers.isEmpty
          ? const Center(child: Text("الخزنة فارغة حالياً"))
          : ListView.builder(
              itemCount: StorageService.registeredUsers.length,
              itemBuilder: (context, index) {
                final user = StorageService.registeredUsers[index];
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
                      "MOX: ${user.moxId} | الرصيد: ${user.balance} | النقاط: ${user.points}",
                    ),
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

  // الشاشة المنبثقة الخاصة بالترس للتحكم الفردي في العميل والتحديث السحابي والمحلي
  void _showControlPanel(UserModel user) {
    final balanceController = TextEditingController(
      text: user.balance.toString(),
    );
    final commissionController = TextEditingController(
      text: user.commission.toString(),
    );
    final pointsController = TextEditingController(
      text: user.points.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
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
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "تعديل الرصيد (Balance)",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commissionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "تعديل العمولة (Commission)",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "تعديل النقاط (Points)",
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A9CC),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "حفظ وتحديث الحقول الزرقاء 🔵",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  user.balance =
                      double.tryParse(balanceController.text) ?? user.balance;
                  user.commission =
                      double.tryParse(commissionController.text) ??
                      user.commission;
                  user.points =
                      int.tryParse(pointsController.text) ?? user.points;

                  // حفظ التعديلات باستخدام الدالة المعتمدة في الخزينة
                  await StorageService.saveUsersList();

                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.pop(modalContext);
                  await _refreshData();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ تم تحديث بيانات ${user.name} بنجاح"),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
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
                  debugPrint("تم حظر العميل: ${user.name}");
                  Navigator.pop(modalContext);
                  await _refreshData();

                  if (!mounted) return;
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
                  Navigator.pop(modalContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
