import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mox_digital_app/admin_panel/app_warehouse_tab.dart';
import 'package:mox_digital_app/admin_panel/services_manager_tab.dart';
import 'package:mox_digital_app/screens/client_store_admin_screen.dart';
import 'package:mox_digital_app/screens/digital_map_screen.dart';
import 'package:mox_digital_app/screens/external_store_front_screen.dart';
import '../models/user_model.dart';
import 'admin_screen.dart';
import 'store_orders_screen.dart';
import 'package:url_launcher/url_launcher.dart';
// استدعاء شاشة الخريطة الرقمية السيادية
// import 'digital_map_screen.dart'; // قم بفك التعليق إذا كانت في ملف منفصل
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color moxBlue = const Color(0xFF28A9CC);

  // متغيرات البطاقة الأولى (التأسيسية) للعميل قابلة للتعديل عند فتح الترس
  bool isEditingCard = false;
  String cardTitle = "البطاقة التأسيسية الأولى";
  String cardDescription = "وصف الخدمة أو المنتج الرقمي الخاص بك هنا...";
  String cardPrice = "0.00";
  String customerWhatsapp = "";
  String customerFacebook = "";
  bool isCardPublished = false;

  // 📇 هيكل البيانات للبطاقات الـ 5 الخاصة بالعميل
  final List<Map<String, dynamic>> _clientCards = List.generate(5, (index) {
    int cardNum = index + 1;
    return {
      "id": cardNum,
      "title": cardNum == 1
          ? "البطاقة التأسيسية الأولى"
          : "البطاقة التأسيسية رقم $cardNum",
      "description":
          "وصف الخدمة أو المنتج الرقمي الخاص بطاقتك رقم $cardNum هنا...",
      "price": "0.00",
      "isRequested": false, // هل طلب العميل اعتمادها من المدير؟
      "isPublished": false, // هل وافق عليها المدير وظهرت في الأصول؟
    };
  });

  // قوائم العمليات والطلبات للعميل
  final List<Map<String, dynamic>> clientOperations = [];

  // بيانات الجلسة الأخيرة للتقارير
  String sessionDate = "";
  String loginTime = "";
  late String logoutTime;

  // حقول الإعدادات المؤقتة لتعديل بيانات العميل
  late TextEditingController _settingsPhoneController;
  late TextEditingController _settingsAddressController;
  late TextEditingController _settingsPasswordController;

  @override
  void initState() {
    super.initState();
    sessionDate = DateTime.now().toString().substring(0, 10);
    _settingsPhoneController = TextEditingController(text: widget.user.phone);
    _settingsAddressController = TextEditingController(
      text: widget.user.address,
    );
    _settingsPasswordController = TextEditingController(text: "");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loginTime = TimeOfDay.now().format(context);
    logoutTime = TimeOfDay.now().format(context);
  }

  @override
  void dispose() {
    _settingsPhoneController.dispose();
    _settingsAddressController.dispose();
    _settingsPasswordController.dispose();
    super.dispose();
  }

  // 🌍 روابط الانتقال السيادية (يمكنك تعديل الروابط هنا بكل سهولة)
  final String linkZaherMasterZat =
      "https://almnzoma-mox.blogspot.com/p/blog-page_557.html";
  final String linkZaherGlobalSystem =
      "https://www.facebook.com/AlmnzomaOnline2";
  final String linkMoxOnline = "https://www.facebook.com/AlmnzomaOnlineMOX";
  final String linkMoxAgents = "https://www.facebook.com/MoxAgents";

  Future<void> _openExternalLink(String urlTitle, String urlString) async {
    if (urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("عذراً، تعذر فتح رابط ($urlTitle)")),
      );
    }
  }

  // 🗺️ الانتقال إلى شاشة خريطة المنتجات الرقمية السيادية
  void _openDigitalMapScreen() {
    Navigator.pop(context); // إغلاق القائمة الجانبية أولاً بأمان
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DigitalMapScreen(
          clientMoxId: widget.user.moxId,
          clientName: widget.user.name,
        ),
      ),
    );
  }

  // 🚪 دالة تنفيذ تسجيل الخروج بالمسطرة والاحترافية
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "تأكيد تسجيل الخروج",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "هل أنت متأكد من رغبتك في تسجيل الخروج من المنظومة أونلاين موكس؟",
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // إغلاق مربع الحوار
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(isMoxIdLogin: false),
                ),
                (route) => false,
              );
            },
            child: const Text("خروج", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin =
        widget.user.role == "admin" ||
        widget.user.accountType == "إدارة" ||
        widget.user.accountType == "مدير" ||
        widget.user.moxId == "MOX249-00010001";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 10),
            Text(
              "مرحباً ${widget.user.name}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: moxBlue),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person,
                      color: Color(0xFF28A9CC),
                      size: 30,
                    ),
                  ),
                ),
              ),
              accountName: Text(
                widget.user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                "هوية MOX: ${widget.user.moxId.isNotEmpty ? widget.user.moxId : 'غير مسجل'}",
              ),
            ),
            // حصنّا زر شاشة المدير ليظهر حصرياً لعميل المدير أو من يمتلك صلاحية الإدارة
            if (isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.red,
                ),
                title: const Text(
                  "بوابة المدير السيادية",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminScreen(),
                    ),
                  );
                },
              ),
            const Divider(),
            // أزرار روابط الانتقال المضافة لكل العملاء في القائمة الجانبية
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "🌍 روابط الانتقال السيادية",
                style: TextStyle(
                  color: moxBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            // 🗺️ زر الخارطة الرقمية في أعلى الأزرار تماماً
            ListTile(
              leading: const Icon(Icons.map_rounded, color: Color(0xFF1B6B80)),
              title: const Text(
                "الخارطة الرقمية",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B6B80),
                ),
              ),
              onTap: _openDigitalMapScreen,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.indigo),
              title: const Text("تحميل وتحديث التطبيق (الهاتف)"),
              onTap: () => _openExternalLink(
                "تحميل وتحديث التطبيق (الهاتف)",
                linkZaherMasterZat,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.teal),
              title: const Text("زاهر المنظومة العالمي"),
              onTap: () => _openExternalLink(
                "زاهر المنظومة العالمي",
                linkZaherGlobalSystem,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text("المنظومة أونلاين MOX"),
              onTap: () =>
                  _openExternalLink("المنظومة أونلاين MOX", linkMoxOnline),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.orange),
              title: const Text("وكلاء موكس"),
              onTap: () => _openExternalLink("وكلاء موكس", linkMoxAgents),
            ),
            const Divider(),
            // تفعيل زر تسجيل الخروج بالمسطرة والاحترافية الحقيقية
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "تسجيل خروج",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // إغلاق الدرج أولاً
                _handleLogout(); // استدعاء نافذة التأكيد والخروج
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoxAlertsCard(currentUser: widget.user),
            const SizedBox(height: 15),

            // اللوجو تحت الشريط العلوي وفي المنتصف تماماً وفوق بطاقة النقاط
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 55,
                    width: 55,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.store,
                      color: Color(0xFF28A9CC),
                      size: 45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "المنظومة أونلاين MOX",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B6B80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // الأزرار الرئيسية في الأعلى
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                _buildDashboardItem(
                  Icons.storefront,
                  "متجر موكس",
                  Colors.indigo,
                  () => _showMoxStoreDialog(context),
                ),
                _buildDashboardItem(
                  Icons.folder_special,
                  "أصول العميل",
                  Colors.teal,
                  () => _showClientAssetsScreen(context),
                ),
                _buildDashboardItem(
                  Icons.analytics,
                  "التقارير",
                  moxBlue,
                  () => _showSessionReportDialog(context),
                ),
                _buildDashboardItem(
                  Icons.payments,
                  "العمليات",
                  Colors.green,
                  () => _showClientOperationsDialog(context),
                ),
                _buildDashboardItem(
                  Icons.settings,
                  "الإعدادات",
                  Colors.orange,
                  () => _showSettingsDialog(context),
                ),
                _buildDashboardItem(
                  Icons.person_search,
                  "حالة الحساب",
                  Colors.blueGrey,
                  () => _showAccountStatusModal(context),
                ),
              ],
            ),

            const SizedBox(height: 25),
            const Text(
              "📌 نافذة المعرفة والسياسات السيادية",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoCard(
              title: "🏛️ من نحن",
              content:
                  "المنظومة أونلاين موكس هي منصة سودانية متخصصة في تطوير المنتجات الرقمية والحلول الذكية للأفراد والشركات.",
              color: Colors.blue[50]!,
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              title: "🔒 سياسة الخصوصية",
              content:
                  "تلتزم المنظومة أونلاين موكس بحماية خصوصية جميع المستخدمين، وتتعامل مع البيانات الشخصية بسرية تامة.",
              color: Colors.green[50]!,
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              title: "📘 طريقة الاستخدام",
              content:
                  "ابدأ رحلتك بإنشاء حساب مجاني داخل تطبيق بنك موكس الرقمي، ثم أكمل بياناتك الأساسية بدقة.",
              color: Colors.orange[50]!,
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              title: "🌍 رؤية MOX",
              content:
                  "تسعى المنظومة أونلاين موكس إلى بناء أكبر منظومة سودانية للأصول الرقمية برقم موحد ورقم MOX.",
              color: Colors.purple[50]!,
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                "جميع الحقوق محفوظة ©️ المنظومة أونلاين موكس ${DateTime.now().year}",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildInfoCard({
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🪟 بطاقة منبثقة لحالة الحساب والبيانات السيادية الشاملة
  void _showAccountStatusModal(BuildContext context) {
    bool hasMox =
        widget.user.moxId.isNotEmpty && widget.user.moxId != "لم يحدد";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // شريط العنوان مع لمسة جمالية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B6B80).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF1B6B80),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "حالة الحساب والملف السيادي",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(thickness: 1.2),
              const SizedBox(height: 10),

              // بطاقة الحالة السيادية بتصميم بارز وفاخر
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasMox
                        ? [Colors.teal.shade50, Colors.green.shade50]
                        : [Colors.orange.shade50, Colors.red.shade50],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasMox
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        hasMox
                            ? Icons.verified_user
                            : Icons.warning_amber_rounded,
                        size: 30,
                        color: hasMox ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasMox
                                ? "حسابك نشط ومعتمد سيادياً"
                                : "حسابك غير نشط",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: hasMox
                                  ? Colors.green[800]
                                  : Colors.red[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasMox
                                ? "رقم MOX: ${widget.user.moxId}"
                                : "سارع بامتلاك رقم موكس السيادي الخاص بك",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // بطاقة تفاصيل ملف العميل الشاملة (الاسم الحقيقي والبيانات)
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.indigo,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "البيانات الشخصية المعتمدة",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          // التأكد من جلب الاسم الحقيقي للعميل بوضوح
                          _buildInfoRow(
                            Icons.badge_outlined,
                            "الاسم الحقيقي",
                            widget.user.name.isNotEmpty
                                ? widget.user.name
                                : "غير مسجل",
                          ),
                          _buildInfoRow(
                            Icons.phone_outlined,
                            "رقم الهاتف",
                            widget.user.phone,
                          ),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            "العنوان",
                            widget.user.address.isNotEmpty
                                ? widget.user.address
                                : 'غير مسجل',
                          ),
                          _buildInfoRow(
                            Icons.admin_panel_settings_outlined,
                            "صلاحية الحساب (Role)",
                            widget.user.role,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // بطاقة الأرصدة والنقاط الاحترافية المتدرجة
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 15,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B6B80), Color(0xFF28A9CC)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF28A9CC,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Colors.amberAccent,
                                size: 28,
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "نقاط الولاء",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                "${widget.user.points} نقطة",
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white24,
                          ),
                          Column(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "رصيد العمولات",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                "${widget.user.commission} ج.س",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // زر الإغلاق الفخم
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B6B80),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "إغلاق النافذة",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // مساعدة لتنسيق صفوف البيانات داخل النافذة
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 🏪 متجر موكس (تم إيقاف الاستيراد المباشر وقصر العرض على ما يعتمده وينشره المدير فقط بالمسطرة)
  void _showMoxStoreDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "🏪 متجر موكس الرقمي",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.indigo, Color(0xFF28A9CC)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 30,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.store,
                                      color: Colors.indigo,
                                      size: 30,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "أهلاً بك في متجر موكس",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "هنا تستعرض المنتجات والبطاقات الرقمية المصرح بها والخدمات والتطبيقات المنشورة حصرياً من المدير.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // مستودع التطبيقات والخدمات (أزرار سيادية تفتح شاشة واسعة ومريحة للقراءة)
                    const Text(
                      "📦 مستودع التطبيقات والخدمات المعتمدة:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 📱 زر التطبيقات المتاحة
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[50],
                        foregroundColor: Colors.indigo,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.indigo.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      onPressed: () {
                        // فتح نافذة منبثقة مستقلة وواسعة لعرض التطبيقات براحة تامة
                        _showSectionDetailsModal(
                          context,
                          "📂 التطبيقات المتاحة (مستودع الإدارة)",
                          const AppWarehouseTab(),
                        );
                      },
                      icon: const Icon(Icons.apps, color: Colors.indigo),
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "📂 التطبيقات المتاحة (معروضة من مستودع الإدارة)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.indigo,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ⚙️ زر الخدمات المتاحة
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[50],
                        foregroundColor: Colors.teal[800],
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      onPressed: () {
                        // فتح نافذة منبثقة مستقلة وواسعة لعرض الخدمات براحة تامة
                        _showSectionDetailsModal(
                          context,
                          "⚙️ الخدمات المتاحة (لوحة المدير)",
                          const ServicesManagerTab(),
                        );
                      },
                      icon: const Icon(
                        Icons.settings_suggest,
                        color: Colors.teal,
                      ),
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "⚙️ الخدمات المتاحة (معروضة من لوحة المدير)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // زر طلبيات المتجر الجديد
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                StoreOrdersScreen(currentUser: widget.user),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_bag, color: Colors.white),
                      label: const Text(
                        "طلبيات المتجر (إرسال طلب جديد)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🪟 دالة مساعدة لفتح شاشة منبثقة واسعة ونظيفة عند الضغط على الزر
  void _showSectionDetailsModal(
    BuildContext context,
    String title,
    Widget contentWidget,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(child: contentWidget),
            ],
          ),
        );
      },
    );
  }

  // 📁 أصول العميل الرقمية ومتجره الالكتروني (النسخة النهائية المقفولة بدون أخطاء)
  void _showClientAssetsScreen(BuildContext context) {
    final String clientStoreUrl =
        "https://mox-2026.vercel.app/store?phone=${widget.user.phone}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctxModal) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            // ignore: unnecessary_nullable_for_final_variable_declarations
            final String? mox = widget.user.moxId;
            final String? gMox = widget.user.guardianMoxId;

            final bool hasValidMoxAccess =
                (mox != null &&
                    mox.trim().isNotEmpty &&
                    mox != "لم يحدد" &&
                    mox.toLowerCase() != 'null') ||
                (gMox != null &&
                    gMox.trim().isNotEmpty &&
                    gMox != "لم يحدد" &&
                    gMox.toLowerCase() != 'null' &&
                    !gMox.startsWith("MOX249-00010001"));

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📁 أصول العميل الرقمية والبطاقات",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF28A9CC),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        // مربع وزر نسخ رابط متجر العميل ومعاينة الصفحة B (ExternalStoreFrontScreen) مباشرة
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "🔗 رابط متجر العميل الخاص",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: const Color(0xFF28A9CC),
                                    ),
                                    onPressed: () {
                                      // إغلاق المودال أولاً والانتقال بسلاسة تامة إلى الصفحة B (المتجر الخارجي)
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ExternalStoreFrontScreen(
                                                user: widget.user,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "معاينة المتجر (الصفحة B)",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      clientStoreUrl,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 18,
                                      color: Colors.indigo,
                                    ),
                                    tooltip: "نسخ الرابط",
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: clientStoreUrl),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "تم نسخ رابط متجر العميل بنجاح",
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // بطاقة بيانات العميل المعتمدة
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.person,
                              color: Colors.indigo,
                            ),
                            title: const Text(
                              "👤 بيانات العميل المعتمدة",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                                fontSize: 14,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "الاسم الحقيقي: ${widget.user.name}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("الهاتف: ${widget.user.phone}"),
                                    const SizedBox(height: 4),
                                    Text("العنوان: ${widget.user.address}"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        if (!hasValidMoxAccess)
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.redAccent),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "⚠️ لم تتم ترقية حساب العميل",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "شارك رابط الترقية الخاص بك لتوثيق هويتك:",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  "https://mox-2026.vercel.app/invite/${widget.user.phone}",
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.teal, Colors.green],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "🌟 بطاقة الهوية السيادية",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "رقم MOX: ${widget.user.moxId != "لم يحدد" ? widget.user.moxId : widget.user.guardianMoxId}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "متجر + ${widget.user.name}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                        const Text(
                          "🛒 إدارة البطاقات للعميل",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 10),

                        ..._clientCards.map((card) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          card['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${card['price']} ج.س",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    card['description'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 15),

                        // زر فتح لوحة إعداد ونشر المتجر (الصفحة A)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClientStoreAdminScreen(user: widget.user),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFF28A9CC),
                          ),
                          label: const Text(
                            "فتح لوحة إعداد ونشر المتجر (الصفحة A)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B6B80),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // نافذة العمليات المخصصة للعميل
  void _showClientOperationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "💳 عمليات وطلبات العميل",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(
                child: clientOperations.isEmpty
                    ? const Center(
                        child: Text(
                          "لا توجد عمليات أو بطاقات منشورة حتى الآن.\nعند طلب بطاقة أو خدمة من متجر موكس ستظهر هنا.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: clientOperations.length,
                        itemBuilder: (context, index) {
                          final op = clientOperations[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: (op["color"] as Color).withValues(
                                alpha: 0.15,
                              ),
                              border: Border.all(color: op["color"] as Color),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.stars,
                                  color: op["color"] as Color,
                                  size: 30,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        op["title"],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: op["color"] as Color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "النوع: ${op["type"]} | التاريخ: ${op["date"]}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // تقارير الجلسة الأخيرة
  void _showSessionReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF28A9CC)),
            SizedBox(width: 8),
            Text(
              "تقرير الجلسة الأخيرة",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ملخص نشاط الجلسة الحالية للمستخدم:",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "📅 تاريخ الجلسة: $sessionDate",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "⏰ زمن الدخول: $loginTime",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "⌛ زمن الخروج (الحالي): $logoutTime",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: moxBlue),
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // الإعدادات (تعديل الاسم الحقيقي، الهاتف، العنوان، وكلمة السر)
  void _showSettingsDialog(BuildContext context) {
    // تعريف الـ Controllers محلياً داخل الدالة لضمان عدم تداخل البيانات ونظافة الذاكرة
    final TextEditingController settingsNameController = TextEditingController(
      text: widget.user.name,
    );
    final TextEditingController settingsPhoneController = TextEditingController(
      text: widget.user.phone,
    );
    final TextEditingController settingsAddressController =
        TextEditingController(text: widget.user.address);
    final TextEditingController settingsPasswordController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "⚙️ إعدادات الحساب الشخصي",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                "يمكنك تعديل بياناتك الشخصية وكلمة المرور الخاصة بك:",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              // حقل الاسم الحقيقي للعميل (لعلاج مشكلة ظهور الاسم السيادي بدلاً عنه)
              TextField(
                controller: settingsNameController,
                decoration: const InputDecoration(
                  labelText: "الاسم الحقيقي",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: settingsPhoneController,
                decoration: const InputDecoration(
                  labelText: "رقم الهاتف",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: settingsAddressController,
                decoration: const InputDecoration(
                  labelText: "العنوان",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: settingsPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "كلمة السر الجديدة",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    widget.user.name = settingsNameController.text;
                    widget.user.phone = settingsPhoneController.text;
                    widget.user.address = settingsAddressController.text;
                    if (settingsPasswordController.text.isNotEmpty) {
                      widget.user.password = settingsPasswordController.text;
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم حفظ التعديلات بنجاح")),
                  );
                },
                child: const Text(
                  "حفظ التعديلات",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MoxAlertsCard extends StatefulWidget {
  final UserModel currentUser;
  const MoxAlertsCard({super.key, required this.currentUser});

  @override
  State<MoxAlertsCard> createState() => _MoxAlertsCardState();
}

class _MoxAlertsCardState extends State<MoxAlertsCard> {
  int _currentIndex = 0;
  late final List<String> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = [
      "🚨 تنبيه MOX: لديك ${widget.currentUser.points} مستوى الاخطاء في شبكة الإحالة السيادية.",
      widget.currentUser.moxId.isNotEmpty
          ? "🌟 تم تفعيل هويتك الرقمية برقم MOX: ${widget.currentUser.moxId}"
          : "⚠️ حسابك لم يُرقَّ بعد، شارك رابط الترقية لتوثيق أصولك.",
      "📌 متجر موكس جاهز لاستقبال طلبات بطاقات العرض والخدمات الرقمية.",
      "🏛️ المنظومة أونلاين: تأكد من تحديث وسائط التواصل لضمان تدفق الأرباح والأصول.",
    ];
  }

  // 📁 دالة أصول العميل الرقمية المعرفة محلياً بالمسطرة
  void _showClientAssetsScreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final String clientStoreUrl =
            "https://mox-2026.vercel.app/store?phone=${widget.currentUser.phone}";
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📁 أصول العميل الرقمية",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                clientStoreUrl,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("نسخ الرابط"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: clientStoreUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم نسخ رابط الأصول بنجاح")),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String clientStoreUrl =
        "https://mox-2026.vercel.app/store?phone=${widget.currentUser.phone}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // بطاقة التنبيهات الأصلية بالمسطرة
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              border: Border.all(color: Colors.amber, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.notification_important,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      _alerts[_currentIndex],
                      key: ValueKey<int>(_currentIndex),
                      style: const TextStyle(
                        color: Colors.brown,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    size: 14,
                    color: Colors.brown,
                  ),
                  tooltip: "التنبيه التالي",
                  onPressed: () {
                    setState(() {
                      _currentIndex = (_currentIndex + 1) % _alerts.length;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 🔗 مربع وزر نسخ رابط أصول العميل الرقمية الحقيقي على المنصة بالمسطرة
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "🔗 رابط أصول العميل الرقمية الحقيقي",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.indigo,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 25),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.folder_shared,
                      size: 14,
                      color: Colors.indigo,
                    ),
                    label: const Text(
                      "عرض الأصول",
                      style: TextStyle(fontSize: 11, color: Colors.indigo),
                    ),
                    onPressed: () {
                      // استدعاء الدالة المحلية المباشرة بالمسطرة
                      _showClientAssetsScreen(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      clientStoreUrl,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Colors.indigo,
                    ),
                    tooltip: "نسخ رابط الأصول",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: clientStoreUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "تم نسخ رابط أصول العميل الرقمية بنجاح",
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
