import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class FinanceManagerTab extends StatefulWidget {
  const FinanceManagerTab({super.key});

  @override
  State<FinanceManagerTab> createState() => _FinanceManagerTabState();
}

class _FinanceManagerTabState extends State<FinanceManagerTab> {
  int financeSubTab = 1;
  List<Map<String, dynamic>> clientsData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    try {
      final dynamic data = await StorageService.getClientsData();
      if (data is List) {
        setState(() {
          clientsData = data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          clientsData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("خطأ في جلب بيانات المالية: $e");
    }
  }

  Future<void> _saveFinanceData() async {
    await StorageService.saveClientsData(clientsData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[150],
      appBar: AppBar(
        title: const Text(
          "إدارة المالية والتحكم السيادي",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF1B6B80),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B6B80)),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFinanceView() {
    if (clientsData.isEmpty) {
      return const Center(
        child: Text(
          "لا توجد بيانات مالية مسجلة حالياً",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    switch (financeSubTab) {
      case 1:
        return _buildCommissionsView();
      case 2:
        return _buildPointsView();
      default:
        return _buildCommissionsView();
    }
  }

  // 1. عملاء العمولات
  Widget _buildCommissionsView() {
    return ListView.builder(
      itemCount: clientsData.length,
      itemBuilder: (context, index) {
        final client = clientsData[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: const Icon(Icons.attach_money, color: Colors.green),
            ),
            title: Text(
              client["name"] ?? "بدون اسم",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "رقم MOX: ${client["guardianMoxId"]!.isNotEmpty ? client["guardianMoxId"] : 'غير مسجل'} | عمولة: ${client["commission"] ?? '0'}",
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "الرصيد",
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      "${client["balance"] ?? '0'} د.س",
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
                  tooltip: "إدارة العمولات والرصيد",
                  onPressed: () => _showEditCommissionDialog(client),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditCommissionDialog(Map<String, dynamic> client) {
    final TextEditingController commissionController = TextEditingController(
      text: client["commission"]?.toString() ?? "0",
    );
    final TextEditingController balanceController = TextEditingController(
      text: client["balance"]?.toString() ?? "0",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "تعديل العمولات والرصيد: ${client["name"]}",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commissionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "حقل العمولات",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "حقل الرصيد",
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
                client["commission"] = commissionController.text;
                client["balance"] = balanceController.text;
              });
              await _saveFinanceData();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ تم حفظ التغييرات وتحديث ملف العميل بنجاح"),
                ),
              );
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3. النقاط
  Widget _buildPointsView() {
    return ListView.builder(
      itemCount: clientsData.length,
      itemBuilder: (context, index) {
        final client = clientsData[index];
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
              client["name"] ?? "عميل",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "رقم MOX: ${client["guardianMoxId"]!.isNotEmpty ? client["guardianMoxId"] : 'غير مسجل'}",
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "النقاط",
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      "${client["points"] ?? '0'} نقطة",
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
                  tooltip: "سحب وتعديل النقاط",
                  onPressed: () => _showEditPointsDialog(client),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPointsDialog(Map<String, dynamic> client) {
    final TextEditingController pointsController = TextEditingController(
      text: client["points"]?.toString() ?? "0",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "سحب وتعديل نقاط: ${client["name"]}",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: pointsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "رصيد النقاط الجديد (للسحب أو التعديل)",
            border: OutlineInputBorder(),
            isDense: true,
          ),
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
                client["points"] = pointsController.text;
              });
              await _saveFinanceData();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "✅ تم تحديث وسحب النقاط وحفظها في ملف العميل بنجاح",
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
