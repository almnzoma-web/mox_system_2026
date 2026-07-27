import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ServicesManagerTab extends StatefulWidget {
  const ServicesManagerTab({super.key});
  @override
  State<ServicesManagerTab> createState() => _ServicesManagerTabState();
}

class _ServicesManagerTabState extends State<ServicesManagerTab> {
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    var data = await ApiService.fetchData("General_Service");
    if (!mounted) return;
    setState(() {
      services = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الخدمات السيادية"),
        backgroundColor: const Color(0xFF1B6B80),
      ),
      body: ListView.builder(
        itemCount: services.length,
        itemBuilder: (context, i) {
          final item = services[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              leading: const Icon(Icons.room_service, color: Colors.purple),
              title: Text(
                item['اسم المنتج'] ?? 'غير معروف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "التصنيف: ${item['نوع التصنيف'] ?? 'عام'} | ${item['السعر بالجنية'] ?? '0'} ج.س",
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(item['الوصف'] ?? 'لا يوجد وصف'),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () =>
                                _launchURL(item['رابط الشرح'] ?? ''),
                            icon: const Icon(Icons.description),
                            label: const Text("شرح"),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                226,
                                232,
                                226,
                              ),
                            ),
                            onPressed: () =>
                                _launchURL("https://wa.me/249115855164"),
                            icon: const Icon(Icons.chat),
                            label: const Text("شراء الآن"),
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
