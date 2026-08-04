import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../data/user_data.dart';

class AdminStoreRequestsScreen extends StatefulWidget {
  const AdminStoreRequestsScreen({super.key});

  @override
  State<AdminStoreRequestsScreen> createState() =>
      _AdminStoreRequestsScreenState();
}

class _AdminStoreRequestsScreenState extends State<AdminStoreRequestsScreen> {
  List<UserModel> pendingUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    await StorageService.ensureLoaded();
    setState(() {
      // فرز العملاء الذين قاموا بطلب النشر ولديها تاريخ نشر أو أصول تحتاج اعتماد
      pendingUsers = registeredUsers
          .where(
            (u) =>
                u.role == 'client' &&
                u.storePublishDate != null &&
                u.storePublishDate!.isNotEmpty,
          )
          .toList();
      isLoading = false;
    });
  }

  // 🌟 اعتماد وتفعيل طلب المتجر من قبل المدير
  Future<void> _approveStore(UserModel clientUser) async {
    // تحديث تاريخ النشر لضمان تفعيل الـ 365 يوماً وتأكيد الاعتماد
    String activeTimestamp = DateTime.now().toIso8601String();

    // تحديث أصول المستخدم لتكون معتمدة isApproved = true
    var approvedAssets = clientUser.myAssets
        .map((asset) => asset.copyWith(isApproved: true))
        .toList();

    UserModel updatedClient = clientUser.copyWith(
      storePublishDate: activeTimestamp,
      myAssets: approvedAssets,
    );

    // تحديث في الذاكرة والقاعدة
    await StorageService.updateUserPartial(updatedClient);

    // تحديث القائمة المحلية
    await _loadPendingRequests();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "✅ تم اعتماد وتنشيط متجر العميل: ${clientUser.name.isNotEmpty ? clientUser.name : clientUser.moxId} بنجاح",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B80),
        title: const Text(
          "طلبات المتاجر السيادية (لوحة المدير)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A9CC)),
            )
          : pendingUsers.isEmpty
          ? const Center(
              child: Text(
                "لا توجد طلبات متاجر معلقة في الوقت الحالي 🛡️",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingUsers.length,
              itemBuilder: (context, index) {
                var client = pendingUsers[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              client.name.isNotEmpty
                                  ? client.name
                                  : "متجر بدون اسم",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B6B80),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "قيد المراجعة",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "رقم موكس: ${client.moxId}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          "المجال التجاري: ${client.address.isNotEmpty ? client.address : 'غير محدد'}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          "الهاتف: ${client.phone}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "البطاقات المختارة للنشر:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ...client.myAssets.map(
                          (asset) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "- ${asset.title} (${asset.description})",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28A9CC),
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _approveStore(client),
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "موافقة وتنشيط المتجر (365 يوم)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
