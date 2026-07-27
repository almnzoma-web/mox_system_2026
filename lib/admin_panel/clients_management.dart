import 'package:flutter/material.dart';
import '../data/user_data.dart';
import '../models/user_model.dart';

class ClientsManager extends StatefulWidget {
  const ClientsManager({super.key});

  @override
  State<ClientsManager> createState() => _ClientsManagerState();
}

class _ClientsManagerState extends State<ClientsManager> {
  String searchQuery = "";

  Future<void> _refreshData() async {
    await loadUsers();
    if (mounted) setState(() {});
  }

  // دالة الحفظ الدائم المباشر للخزينة المحلية
  Future<void> _saveLocalData() async {
    await saveUsers();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = registeredUsers
        .where(
          (u) =>
              u.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              u.phone.contains(searchQuery) ||
              u.moxId.contains(searchQuery),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة العملاء السيادية"),
        backgroundColor: const Color(0xFF1B6B80),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "بحث عن عميل (الاسم، الهاتف، أو رقم MOX)",
                prefixIcon: Icon(Icons.search, color: Color(0xFF28A9CC)),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text("لا يوجد عملاء في الخزينة حالياً."))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF28A9CC,
                            ).withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF28A9CC),
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "رقم MOX: ${user.moxId.isNotEmpty ? user.moxId : 'غير محدد'} | الهاتف: ${user.phone}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Color(0xFF1B6B80),
                            ),
                            tooltip: "تعديل وإضافة رقم MOX",
                            onPressed: () => _showEditMoxPanel(user),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: const Color(0xFF878EDB),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  void _showEditMoxPanel(UserModel user) {
    final TextEditingController moxController = TextEditingController(
      text: user.moxId,
    );

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "تعيين رقم MOX للعميل: ${user.name}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "أدخل رقم MOX يدوياً:",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moxController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: "رقم MOX",
                hintText: "MOX249-00010001",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6B80),
                  ),
                  onPressed: () async {
                    user.moxId = moxController.text.trim();

                    // حفظ التعديلات في الذاكرة الدائمة ومعالجة آمنة لـ context
                    await _saveLocalData();

                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    await _refreshData();

                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "✅ تمت إدراج وحفظ رقم MOX في الذاكرة الدائمة بنجاح",
                        ),
                        duration: Duration(milliseconds: 1200),
                      ),
                    );
                  },
                  child: const Text(
                    "حفظ",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
