// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../data/user_data.dart';
import '../services/storage_service.dart';

class AdminStoreRequestsScreen extends StatefulWidget {
  const AdminStoreRequestsScreen({super.key});

  @override
  State<AdminStoreRequestsScreen> createState() =>
      _AdminStoreRequestsScreenState();
}

class _AdminStoreRequestsScreenState extends State<AdminStoreRequestsScreen> {
  List<UserModel> _pendingStores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingStores();
  }

  Future<void> _loadPendingStores() async {
    await StorageService.ensureLoaded();
    setState(() {
      // جلب المستخدمين الذين لديهم طلبات متاجر أو بحاجة لمراجعة
      _pendingStores = registeredUsers
          .where(
            (u) => u.storePublishDate != null && u.storePublishDate!.isNotEmpty,
          )
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _approveStore(UserModel user) async {
    UserModel approvedUser = user.copyWith(
      role: 'reviewed_active',
      storePublishDate: DateTime.now().toIso8601String(),
    );

    await StorageService.updateUserPartial(approvedUser);
    await _loadPendingStores();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ تم اعتماد وتنشيط المتجر السيادي بنجاح بالمسطرة!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: const Text(
          "إدارة طلبات المتاجر السيادية",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
            )
          : _pendingStores.isEmpty
          ? const Center(
              child: Text(
                "لا توجد طلبات متاجر معلقة حالياً 📭",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingStores.length,
              itemBuilder: (context, index) {
                var user = _pendingStores[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              user.name.isNotEmpty
                                  ? user.name
                                  : "متجر بدون اسم",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B6B80),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.moxId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "المجال التجاري: ${user.address.isNotEmpty ? user.address : 'غير محدد'}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "هاتف التواصل: ${user.phone}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _approveStore(user),
                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text(
                                "اعتماد وتنشيط",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
