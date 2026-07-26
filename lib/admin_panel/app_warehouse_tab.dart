import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AppWarehouseTab extends StatefulWidget {
  const AppWarehouseTab({super.key});

  @override
  State<AppWarehouseTab> createState() => _AppWarehouseTabState();
}

class _AppWarehouseTabState extends State<AppWarehouseTab> {
  List<Map<String, dynamic>> apps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    final data = await ApiService.fetchData("App_Warehouse");
    if (!mounted) return;
    setState(() {
      apps = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  Future<void> _launchWhatsApp(String message) async {
    final Uri url = Uri.parse(
      "https://wa.me/249115855164?text=${Uri.encodeComponent(message)}",
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // نافذة إدخال رقم MOX المنبثقة بدون فحص، ثم فتح رابط التحميل مباشرة
  void _showMoxNumberDialog(String downloadUrl) {
    final TextEditingController moxController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "إدخال رقم MOX",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B6B80),
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "الرجاء إدخال رقم MOX الخاص بك للمتابعة إلى رابط التحميل:",
                style: TextStyle(fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: moxController,
                decoration: InputDecoration(
                  labelText: "رقم MOX",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.security,
                    color: Color(0xFF1B6B80),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B6B80),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // إغلاق النافذة المنبثقة
                _launchURL(downloadUrl); // فتح رابط التحميل مباشرة بدون فحص
              },
              child: const Text("متابعة للتحميل"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1B6B80)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "مستودع تطبيقات MOX السيادي",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B6B80),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: apps.length,
        itemBuilder: (context, i) {
          final app = apps[i];
          final String downloadLink = app['رابط التحميل'] ?? '';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.apps, color: Colors.blue),
              title: Text(
                app['اسم التطبيق'] ?? 'غير معروف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("حالة النظام: ${app['الحالة'] ?? 'نشط'}"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(
                        app['الوصف'] ?? 'لا يوجد وصف',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "التمليك: \$${app['سعر التمليك بالدولار'] ?? '0'} | اشتراك: \$${app['سعر الاشتراك السنوي بالدولار'] ?? '0'} | أقساط: \$${app['سعر الأقساط بالدولار'] ?? '0'}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                        ),
                      ),
                      const SizedBox(height: 15),
                      // الأزرار الثلاثة المنظمة باحترافية (رابط شرح، طلب التطبيق، رابط التحميل)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                _launchURL(app['رابط الشرح'] ?? ''),
                            icon: const Icon(Icons.description, size: 16),
                            label: const Text("رابط شرح"),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _launchWhatsApp(
                              "أريد طلب التطبيق: ${app['اسم التطبيق']}",
                            ),
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text("طلب التطبيق"),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B6B80),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showMoxNumberDialog(downloadLink),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text("رابط التحميل"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
