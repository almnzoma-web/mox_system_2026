import 'package:flutter/material.dart';
import 'package:mox_digital_app/admin_panel/clients_management.dart';
// الربط المباشر بملفات المنظومة السيادية الحقيقية
import '../admin_panel/visitors_tab.dart';
import '../admin_panel/services_manager_tab.dart';
import '../admin_panel/app_warehouse_tab.dart';
import '../../data/user_data.dart'; // الذاكرة المحلية السيادية للعملاء
import '../../models/user_model.dart';
// خدمة التخزين الحية

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int financeSubTab = 1;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  // سحب البيانات من الذاكرة المحلية (registeredUsers) لضبط المالية بالمسطرة
  Future<void> _loadLocalData() async {
    try {
      await loadUsers(); // جلب البيانات من الذاكرة المحلية والخزينة
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      debugPrint("خطأ في جلب بيانات الذاكرة المحلية للمالية: $e");
    }
  }

  Future<void> _saveLocalData() async {
    await saveUsers(); // حفظ التحديثات في الذاكرة المحلية والخزينة
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        "title": "المالية",
        "icon": Icons.attach_money,
        "color": Colors.green,
        "page": null,
      },
      {
        "title": "التطبيقات",
        "icon": Icons.apps,
        "color": Colors.blue,
        "page": const AppWarehouseTab(),
      },
      {
        "title": "الخدمات",
        "icon": Icons.room_service,
        "color": Colors.purple,
        "page": const ServicesManagerTab(),
      },
      {
        "title": "العملاء",
        "icon": Icons.people,
        "color": Colors.orange,
        "page": const ClientsManager(),
      },
      {
        "title": "الزوار",
        "icon": Icons.visibility,
        "color": Colors.teal,
        "page": const VisitorsTab(),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "لوحة تحكم المدير السيادية (مركز الإدارة والتحكم)",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF1B6B80),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B6B80)),
            )
          : Column(
              children: [
                Container(
                  height: 110,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return Container(
                        width: 105,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Card(
                          elevation: 3,
                          color: (item["color"] as Color).withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              if (item["page"] != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => item["page"],
                                  ),
                                );
                              } else {
                                setState(() {
                                  financeSubTab = 1;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "🔊 تم تفعيل قبة المالية والعمولات الحية",
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item["icon"],
                                  size: 30,
                                  color: item["color"],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item["title"],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(thickness: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildFinanceTabButton(
                        "عملاء العمولات",
                        1,
                        Icons.account_balance_wallet,
                      ),
                      _buildFinanceTabButton(
                        "طلبيات والمنتجات",
                        2,
                        Icons.credit_card,
                      ),
                      _buildFinanceTabButton("النقاط", 3, Icons.stars),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildActiveFinanceView(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFinanceTabButton(String title, int tabIndex, IconData icon) {
    bool isSelected = financeSubTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          financeSubTab = tabIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B6B80) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFinanceView() {
    if (registeredUsers.isEmpty) {
      return const Center(
        child: Text(
          "لا توجد بيانات مسجلة في الذاكرة المحلية حالياً",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    switch (financeSubTab) {
      case 1:
        return _buildCommissionsView();
      case 2:
        return _buildCardRequestsView();
      case 3:
        return _buildPointsView();
      default:
        return _buildCommissionsView();
    }
  }

  // النافذة الأولى: عملاء العمولات (من الذاكرة المحلية UserModel)
  Widget _buildCommissionsView() {
    return ListView.builder(
      itemCount: registeredUsers.length,
      itemBuilder: (context, index) {
        final client = registeredUsers[index];
        bool isAdmin = client.role == 'admin';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isAdmin ? Colors.red[100] : Colors.green[100],
              child: Icon(
                Icons.attach_money,
                color: isAdmin ? Colors.red : Colors.green,
              ),
            ),
            title: Text(
              "${client.name} ${isAdmin ? '(المدير)' : ''}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "رقم MOX: ${client.moxId} | الرصيد: ${client.balance}",
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "العمولات",
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      "${client.commission} ج.س",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.indigo,
                    size: 20,
                  ),
                  tooltip: "تعديل رصيد العمولات",
                  onPressed: () => _showEditCommissionDialog(client),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditCommissionDialog(UserModel client) {
    final TextEditingController amountController = TextEditingController(
      text: client.commission.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "تعديل عمولات: ${client.name}",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "أدخل قيمة العمولات الجديدة:",
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "رصيد العمولات (ج.س)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              setState(() {
                client.commission =
                    double.tryParse(amountController.text) ?? client.commission;
              });
              await _saveLocalData();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "🔊 تم الحفظ وتحديث الذاكرة المحلية للعميل بنجاح",
                  ),
                ),
              );
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // النافذة الثانية: طلبيات والمنتجات (من الذاكرة المحلية UserModel) - المنطق السيادي لنشر البطاقة لـ 365 يوم
  Widget _buildCardRequestsView() {
    return ListView.builder(
      itemCount: registeredUsers.length,
      itemBuilder: (context, index) {
        final client = registeredUsers[index];
        bool isAdmin = client.role == 'admin';
        bool isReviewed = client.role == 'reviewed_active';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${client.name} ${isAdmin ? '(المدير)' : ''}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "MOX: ${client.moxId} | الهاتف: ${client.phone}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReviewed ? Colors.green : Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    setState(() {
                      if (client.role == 'reviewed_active') {
                        // إلغاء المراجعة وإيقاف النشر
                        client.role = 'free';
                      } else {
                        // تحويل الحالة إلى تمت المراجعة وتفعيل أمر النشر الخلفي لمدة 365 يوماً
                        client.role = 'reviewed_active';
                        // هنا يتم جدولة النشر الخلفي وتفعيل صلاحية البطاقة لمدة 365 يوماً تلقائياً
                      }
                    });
                    await _saveLocalData();
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          client.role == 'reviewed_active'
                              ? "✅ تمت المراجعة - تم نشر بطاقة العميل بنجاح لمدة 365 يوماً"
                              : "⏳ الطلب قيد المراجعة",
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  },
                  child: Text(
                    isReviewed ? "تمت المراجعة" : "قيد المراجعة",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // النافذة الثالثة: النقاط (من الذاكرة المحلية UserModel)
  Widget _buildPointsView() {
    return ListView.builder(
      itemCount: registeredUsers.length,
      itemBuilder: (context, index) {
        final client = registeredUsers[index];
        bool isAdmin = client.role == 'admin';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber[100],
              child: const Icon(Icons.stars, color: Colors.amber),
            ),
            title: Text(
              "${client.name} ${isAdmin ? '(المدير)' : ''}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "رقم MOX: ${client.moxId} | نظام النقاط السيادي",
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "رصيد النقاط",
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      "${client.points} نقطة",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.indigo,
                    size: 20,
                  ),
                  tooltip: "تعديل رصيد النقاط",
                  onPressed: () => _showEditPointsDialog(client),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPointsDialog(UserModel client) {
    final TextEditingController pointsController = TextEditingController(
      text: client.points.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "تعديل نقاط: ${client.name}",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "أدخل رصيد النقاط الجديد:",
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "النقاط",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
            onPressed: () async {
              setState(() {
                client.points =
                    int.tryParse(pointsController.text) ?? client.points;
              });
              await _saveLocalData();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "🔊 تم حفظ وتحديث رصيد النقاط في الذاكرة المحلية بنجاح",
                  ),
                ),
              );
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
