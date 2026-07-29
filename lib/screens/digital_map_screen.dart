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

class _DigitalMapScreenState extends State<DigitalMapScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _isLoading = true;
  String _errorMessage = "";
  Map<String, dynamic> _clientData = {};

  late AnimationController _radarController;

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
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _fetchClientMapData();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // دالة جلب بيانات العميل من شيت قوقل عبر الـ API
  Future<void> _fetchClientMapData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });

      final uri = Uri.parse(
        '$_scriptUrl?moxId=${widget.clientMoxId}&name=${Uri.encodeComponent(widget.clientName)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] != null) {
          setState(() {
            _errorMessage = "لا توجد بيانات مسجلة لهذا العميل في قوقل حالياً.";
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

    bool hasDataInGoogle = _clientData.isNotEmpty && _errorMessage.isEmpty;

    List<Map<String, dynamic>> activeAssets = _mapAssets.where((asset) {
      String val = _clientData[asset['key']]?.toString().trim() ?? "";
      bool isYes = val.toLowerCase() == 'نعم';
      bool matchesSearch = asset['key'].contains(_searchQuery);
      return isYes && matchesSearch;
    }).toList();

    List<Map<String, dynamic>> missingAssets = _mapAssets.where((asset) {
      String val = _clientData[asset['key']]?.toString().trim() ?? "";
      return val.toLowerCase() != 'نعم';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          "🗺️ الخريطة الاستراتيجية للأصول الرقمية",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: _fetchClientMapData,
            tooltip: "تحديث الرادار",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : !hasDataInGoogle
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.tealAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        size: 60,
                        color: Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "عذراً، لا توجد بيانات مدرجة لهذا العميل في قوقل",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "لم يتم رصد أي أصول رقمية مسجلة في الشيت السيادي حالياً. ابدأ بتسجيل الأصول لتظهر خريطتك الرقمية المتوهجة بالكامل.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _fetchClientMapData,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        "إعادة فحص الرادار",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.teal,
                                radius: 14,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "المالك: $clientName",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.tealAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              "مـوكس: $moxId",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "ابحث في محطات الخريطة...",
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.tealAccent,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
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
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A),
                              Colors.teal.shade900.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.tealAccent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withValues(alpha: 0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "🌐 نقاط المحاور الإستراتيجية (الخريطة الحية)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.tealAccent,
                                  ),
                                ),
                                Icon(
                                  Icons.public,
                                  color: Colors.tealAccent.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            activeAssets.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "لا توجد محطات مفعلة مطابقة لبحثك الحالي",
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: 1.0,
                                        ),
                                    itemCount: activeAssets.length,
                                    itemBuilder: (context, index) {
                                      final asset = activeAssets[index];
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF1E293B,
                                          ).withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: asset['color'].withValues(
                                              alpha: 0.6,
                                            ),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: asset['color'].withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              asset['icon'],
                                              color: asset['color'],
                                              size: 26,
                                            ),
                                            const SizedBox(height: 6),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),
                      const Text(
                        "🚀 آفاق استثمارية مفقودة (لم تُفعل بعد)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      ...missingAssets.map((missing) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                missing['icon'],
                                color: Colors.orangeAccent,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              missing['key'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: const Text(
                              "محطة غير مفعّلة في خريطتك الحالية",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                minimumSize: const Size(70, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "🚀 طلب تفعيل محطة: ${missing['key']} جاري إرساله للمدير",
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                "تفعيلها الآن",
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
