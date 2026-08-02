import 'package:flutter/material.dart';
import '../models/user_model.dart';

class DigitalMapScreen extends StatefulWidget {
  final UserModel user; // استقبال كائن المستخدم السيادي لتحديد حالته ورقم موكس

  const DigitalMapScreen({
    super.key,
    required this.user,
    required String clientName,
    required String clientMoxId,
  });

  @override
  State<DigitalMapScreen> createState() => _DigitalMapScreenState();
}

class _DigitalMapScreenState extends State<DigitalMapScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final bool _isLoading =
      false; // تم ضبطه كـ final لتكون الشاشة نظيفة ومستقرة تماماً بالمسطرة
  late final AnimationController _radarController;

  // قائمة الحقول الـ 12 المطلوبة للخريطة الرقمية (مفصولة ومستقلة تماماً عن قوقل)
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
  }

  @override
  void dispose() {
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // دالة إظهار الرسالة الفاخرة في المنتصف عند النقر على تفعيل أي محطة مفقودة
  void _showLuxuryStoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: Colors.tealAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  "تنبيه سيادي",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "الرجاء الانتقال إلى متجر موكس",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "حسناً",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String clientName = widget.user.name.isNotEmpty
        ? widget.user.name
        : "العميل الكريم";
    final String moxId = widget.user.moxId.isNotEmpty
        ? widget.user.moxId
        : "حر/مجاني";

    // تفعيل أول محطتين افتراضياً كأصول نشطة وإدراج والباقي كآفاق مفقودة لجميع العملاء بالمسطرة
    List<Map<String, dynamic>> activeAssets = _mapAssets.where((asset) {
      bool matchesSearch = asset['key'].contains(_searchQuery);
      bool isActiveByDefault =
          (asset['key'] == "متجر موكس" || asset['key'] == "موقع محتوى");
      return isActiveByDefault && matchesSearch;
    }).toList();

    List<Map<String, dynamic>> missingAssets = _mapAssets.where((asset) {
      bool isActiveByDefault =
          (asset['key'] == "متجر موكس" || asset['key'] == "موقع محتوى");
      return !isActiveByDefault;
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
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✨ تم تحديث الخريطة بنجاح"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: "تحديث الرادار",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
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
                              onPressed:
                                  _showLuxuryStoreDialog, // فتح الرسالة الفاخرة الموحدة في المنتصف
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
