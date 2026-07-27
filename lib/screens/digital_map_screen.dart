import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DigitalMapScreen extends StatefulWidget {
  final String clientMoxId; // رقم موكس للبحث الجلدي المباشر من الشيت
  final String clientName; // أو اسم العميل كبديل للبحث

  const DigitalMapScreen({
    super.key,
    required this.clientMoxId,
    required this.clientName,
  });

  @override
  State<DigitalMapScreen> createState() => _DigitalMapScreenState();
}

class _DigitalMapScreenState extends State<DigitalMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _isLoading = true;
  String _errorMessage = "";
  Map<String, dynamic> _clientData = {};

  // رابط الـ Web App الخاص بك في Google Apps Script
  final String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbxlV-5aj5QRePSIKtcinOUhgbPz4xha_XgmogohVrdDAhpFcU64LBNQivIKa77o48C8/exec";

  // قائمة الحقول الـ 12 المطلوبة للخريطة الرقمية
  final List<Map<String, dynamic>> _mapAssets = [
    {"key": "موقع محتوى", "icon": Icons.article_rounded, "color": Colors.blue},
    {
      "key": "متجر الكتروني",
      "icon": Icons.storefront_rounded,
      "color": Colors.orange,
    },
    {"key": "متجر موكس", "icon": Icons.shield_rounded, "color": Colors.teal},
    {
      "key": "صفحة فيسبوك احترافية",
      "icon": Icons.facebook_rounded,
      "color": Colors.indigo,
    },
    {
      "key": "قروب فيسبوك ينشر تلقائي",
      "icon": Icons.group_rounded,
      "color": Colors.blueAccent,
    },
    {
      "key": "QR فيسبوك",
      "icon": Icons.qr_code_2_rounded,
      "color": Colors.purple,
    },
    {"key": "QR واتس", "icon": Icons.qr_code_rounded, "color": Colors.green},
    {
      "key": "QR موقع جغرافي",
      "icon": Icons.map_rounded,
      "color": Colors.redAccent,
    },
    {
      "key": "QR موقع إلكتروني",
      "icon": Icons.web_rounded,
      "color": Colors.cyan,
    },
    {
      "key": "براند",
      "icon": Icons.workspace_premium_rounded,
      "color": Colors.amber,
    },
    {
      "key": "تطبيق حاسوب",
      "icon": Icons.desktop_windows_rounded,
      "color": Colors.blueGrey,
    },
    {"key": "اخرى", "icon": Icons.star_rounded, "color": Colors.deepOrange},
  ];

  @override
  void initState() {
    super.initState();
    _fetchClientMapData();
  }

  // دالة جلب بيانات العميل من شيت قوقل عبر الـ API
  Future<void> _fetchClientMapData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });

      // بناء رابط الطلب مع المعلمات
      final uri = Uri.parse(
        '$_scriptUrl?moxId=${widget.clientMoxId}&name=${Uri.encodeComponent(widget.clientName)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] != null) {
          setState(() {
            _errorMessage = "لم يتم العثور على بيانات لهذا العميل في الشيت.";
            _isLoading = false;
          });
        } else {
          setState(() {
            _clientData = Map<String, dynamic>.from(data);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              "فشل الاتصال بخادم الشيت (رمز الخطأ: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء جلب البيانات: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String clientName = _clientData['اسم العميل'] ?? widget.clientName;
    final String moxId = _clientData['رقم موكس'] ?? widget.clientMoxId;

    // تصفية المنتجات التي تحتوي على كلمة "نعم"
    List<Map<String, dynamic>> activeAssets = _mapAssets.where((asset) {
      String val = _clientData[asset['key']]?.toString().trim() ?? "";
      bool isYes = val.toLowerCase() == 'نعم';
      bool matchesSearch = asset['key'].contains(_searchQuery);
      return isYes && matchesSearch;
    }).toList();

    // تصفية المنتجات الخالية لتحفيز العميل
    List<Map<String, dynamic>> missingAssets = _mapAssets.where((asset) {
      String val = _clientData[asset['key']]?.toString().trim() ?? "";
      return val.toLowerCase() != 'نعم';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B6B80),
        title: const Text(
          "🗺️ خريطة المنتجات الرقمية",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: "الرجوع للصفحة الرئيسية",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchClientMapData,
            tooltip: "تحديث البيانات",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B6B80)),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B6B80),
                      ),
                      onPressed: _fetchClientMapData,
                      child: const Text(
                        "إعادة المحاولة",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // شريط البحث العلوي وبطاقة التعريف بالعميل
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "المالك: $clientName",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              "رقم موكس: $moxId",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "ابحث في الخريطة الرقمية...",
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF1B6B80),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(15),
                    children: [
                      const Text(
                        "📍 النقاط المفعلة على الخريطة",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1B6B80),
                        ),
                      ),
                      const SizedBox(height: 10),

                      activeAssets.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Text(
                                "لا توجد منتجات مفعلة مطابقة للبحث حالياً",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.1,
                                  ),
                              itemCount: activeAssets.length,
                              itemBuilder: (context, index) {
                                final asset = activeAssets[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        asset['color'].withValues(alpha: 0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: asset['color'].withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: asset['color'].withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        asset['icon'],
                                        color: asset['color'],
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          asset['key'],
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      const SizedBox(height: 25),
                      const Text(
                        "🚀 آفاق استثمارية مفقودة (سارع بامتلاكها)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      ...missingAssets.map((missing) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade50,
                              child: Icon(
                                missing['icon'],
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              missing['key'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: const Text(
                              "هذا الأصل غير مفعّل في خريطتك الرقمية",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B6B80),
                                minimumSize: const Size(70, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "🚀 طلب امتلاك: ${missing['key']} قيد التفعيل عبر المدير",
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                "امتلكه الآن",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
