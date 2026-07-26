import 'package:flutter/material.dart';
import '../data/user_data.dart';
import '../models/user_model.dart';

class ClientsManagerTab extends StatefulWidget {
  const ClientsManagerTab({super.key});

  @override
  State<ClientsManagerTab> createState() => _ClientsManagerTabState();
}

class _ClientsManagerTabState extends State<ClientsManagerTab> {
  String searchQuery = "";

  Future<void> _refreshData() async {
    await loadUsers();
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
              u.moxId.contains(searchQuery) ||
              u.phone.contains(searchQuery),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة العملاء"),
        backgroundColor: const Color(0xFF1B6B80),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "بحث عن عميل (الاسم، رقم MOX، أو الهاتف)",
                prefixIcon: Icon(Icons.search, color: Color(0xFF28A9CC)),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(
                    child: Text("لا توجد بيانات عملاء مسجلة حالياً."),
                  )
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
                            "MOX: ${user.moxId} | الهاتف: ${user.phone}",
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () => _showClientControlPanel(context, user),
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

  void _showClientControlPanel(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "إدارة العميل: ${user.name}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
              ),
            ),
            const SizedBox(height: 12),
            Text("رقم الهاتف: ${user.phone}"),
            const SizedBox(height: 8),
            Text(
              "رقم MOX الحالي: ${user.moxId.isNotEmpty ? user.moxId : 'غير محدد'}",
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6B80),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("تم", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
