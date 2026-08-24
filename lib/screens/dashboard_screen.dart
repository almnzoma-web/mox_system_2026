import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:mox_digital_app/models/marketing_card.dart';
import 'package:mox_digital_app/services/storage_service.dart';
import 'package:mox_digital_app/admin_panel/app_warehouse_tab.dart';
import 'package:mox_digital_app/admin_panel/services_manager_tab.dart';
import 'package:mox_digital_app/screens/client_store_admin_screen.dart';
import 'package:mox_digital_app/screens/digital_map_screen.dart';
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
      "https://almnzoma-mox.blogspot.com/p/blog-page_84.html";
  final String linkZaherGlobalSystem =
      "https://www.facebook.com/AlmnzomaOnline2";
  final String linkMoxOnline =
      "https://almnzoma-mox.blogspot.com/2026/08/mox-2026-digtial-bank-app.html";
  final String linkMoxAgents =
      "https://almnzoma-mox.blogspot.com/p/blog-page_02.html";

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
          user: widget.user,
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
          "هل أنت متأكد من رغبتك في تسجيل الخروج من بنك موكس الرقمي الآن؟",
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
        widget.user.moxId == "ID-005000" ||
        widget.user.role == "admin" ||
        widget.user.accountType == "إدارة" ||
        widget.user.accountType == "مدير" ||
        widget.user.guardianMoxId == "MOX249-00010001";

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
                "هوية MOX: ${widget.user.guardianMoxId!.isNotEmpty ? widget.user.guardianMoxId : 'حساب مجاني'}",
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
              title: const Text("ترقية حسابك"),
              onTap: () =>
                  _openExternalLink("المنظومة أونلاين MOX", linkMoxOnline),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.orange),
              title: const Text("الادوات المجانية في موكس"),
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
                    "المنظومة أونلاين موكس",
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
              title: "🌍 رؤية MOX والمنظومة المتكاملة",
              content:
                  "🟦 تطبيق الهاتف والويب | بنك موكس الرقمي MOX\n\n"
                  "مرحبًا بك في عالم MOX\n\n"
                  "مرحبًا بك في المنظومة أونلاين MOX؛ رفيقك في عالم التحول الرقمي، ومنصة متخصصة في المنتجات والخدمات الرقمية.\n\n"
                  "هنا تبدأ من حساب مجاني، وتنتقل تدريجيًا إلى امتلاك هويتك الرقمية ورقم MOX وموقعك الرقمي، وصولًا إلى منظومة متكاملة لإدارة حضورك وأعمالك في العالم الرقمي.\n\n"
                  "MOX ليست مجرد تطبيق… بل بوابة لبناء عالمك الرقمي.\n\n"
                  "🟪 ماذا وفرنا لك؟\n"
                  "📱 تطبيق هاتف وتطبيق ويب: تستطيع من خلالهما الوصول إلى حسابك وإدارة خدماتك الرقمية بسهولة.\n"
                  "🌐 أصول العميل الرقمية: منصة تتيح لك بناء موقعك الرقمي خلال دقائق، وفق الباقة التي تختارها، دون الحاجة إلى معرفة تقنية معقدة.\n"
                  "🗺️ خارطة رقمية خاصة بك: جهزنا لك مساحة رقمية مرتبطة بهويتك، تساعدك في تنظيم حضورك الرقمي والتعرف على منتجات وخدمات MOX.\n"
                  "✍️ أداة التوقيع الرقمي: أداة ذكية للتوقيع الرقمي الرسمي، يمكنك استخدامها مجانًا مدى الحياة وفق الخدمات المتاحة داخل المنظومة.\n\n"
                  "🟦 عالم MOX… وأنت جزء منه\n"
                  "🔵 أولًا | ابدأ مجانًا: انضم إلى عالم MOX وافتح حسابًا مجانيًا دون الحاجة إلى شراء باقة.\n"
                  "🔵 ثانيًا | حمّل التطبيق: يمكنك تنزيل تطبيق الهاتف من متجر MOX، وستجد رابط التحميل في القائمة الرئيسية. كما يمكنك استخدام المنصة مباشرة عبر الويب إذا كنت تفضل عدم استخدام تطبيق الهاتف.\n"
                  "🔵 ثالثًا | امتلك حسابك: ابدأ بحسابك المجاني واستكشف عالم MOX ومنتجاته وخدماته.\n"
                  "🔵 رابعًا | انتقل إلى الحساب الاحترافي: يمكنك ترقية حسابك للحصول على رقم MOX، وهو هويتك الرقمية الرسمية داخل المنظومة. ويتيح لك رقم MOX الوصول إلى خدمات وأصول رقمية احترافية، من بينها موقع رقمي في شكل متجر يحتوي على 5 رفوف/بطاقات/أقسام وفق الباقة.\n"
                  "🔵 خامسًا | رقم MOX هو هويتك الرقمية: بعد امتلاك رقم MOX، يصبح الرقم وسيلة الدخول الرسمية للحسابات الاحترافية داخل التطبيق، بدلًا من رقم الهاتف.\n"
                  "🔵 سادسًا | استخدم MOX عبر الويب: لا تحتاج إلى هاتف ذكي لاستخدام المنظومة. يمكنك الدخول إلى تطبيق MOX عبر رابط الويب الخاص به واستخدام خدماتك مباشرة من المتصفح.\n"
                  "🔵 سابعًا | ابنِ موقعك خلال دقائق: جعلنا إنشاء موقعك أو متجرك الرقمي عملية بسيطة. بدل أن تبحث عن مطور ومصمم وتنتظر أيامًا… ابدأ بنفسك خلال دقائق.\n\n"
                  "🟧 قاعدة الأسعار في بنك MOX الرقمي\n"
                  "تعتمد منظومة الأسعار على وحدة موكس النمطية (MDU | MOX Digital Unit) ولها وحدة قياس أصغر تسمى نقطة MDU وتعادل 1% من وحدة موكس النمطية.\n"
                  "يتم تحديد السعر الأساسي لنقطة MDU وفق القيمة السوقية المعتمدة في منظومة MOX.\n"
                  "السعر الأساسي لنقطة MDU = 5.55 دولار أمريكي.\n"
                  "أما السعر مقابل الجنيه السوداني، فتوجد حاليًا قيمة مدعومة لانطلاقة بنك MOX الرقمي ضمن خطة MOX لدعم العملاء، ويمكن معرفة السعر الحالي من منصات المنظومة أونلاين MOX ومتجر MOX داخل التطبيق.\n\n"
                  "🟪 كيف تُبنى قيمة منتجات MOX؟\n"
                  "تُطرح الباقات والخدمات كنسب من القيمة السوقية لوحدة MOX الرقمية. وبالتالي: نقطة MDU = 1% من القيمة السوقية لوحدة MOX الرقمية. وتتيح منظومة MOX للعميل، وفق الشروط والبرامج المعتمدة، الوصول إلى قيمة الوحدة الرقمية من خلال النشاط التسويقي وبناء شبكة العملاء.\n\n"
                  "🟦 برنامج الوكيل ونظام MDU\n"
                  "1️⃣ الاشتراك في باقة الهبّابة: تبدأ رحلة الوكيل من خلال الاشتراك في باقة الهبّابة VIP.\n"
                  "2️⃣ فتح سجل وكيل: بعد استيفاء الشروط، يحصل العميل على سجل وكيل داخل المنظومة.\n"
                  "3️⃣ امتلاك حزمة MDU: يحصل الوكيل على حزمة تسويقية تتكون من 10 مولات تسويقية وكل مول يستوعب 5 عملاء، ويستطيع الوكيل طرح البطاقات والرفوف والأقسام للعملاء التابعين له وفق أسعار MOX المعتمدة. وعند تسجيل العميل الجديد، يقوم بإدراج رقم MOX الخاص الوكيل في خانة الوصي. ويُمنح الوكيل مقابل كل عميل 100 نقطة عميل (نقطة العميل تختلف عن نقطة MDU).\n"
                  "4️⃣ الوصول إلى العميل رقم 50: يمنح بنك MOX الوكيل حزمة المول أو المتجر بقيمة مخفضة تصل إلى 50% وفق البرنامج المعتمد. وعند الوصول إلى العميل رقم 50، يمكن أن تعادل القيمة المتحققة القيمة الكلية لوحدة MOX الرقمية وفق شروط البرنامج.\n"
                  "5️⃣ أرباح إضافية: يمكن للوكيل تحقيق أرباح إضافية تعادل 5% من قيمة كل عميل يمتلك منتجًا رقميًا كبيرًا في متجر MOX وفق شروط البرنامج.\n\n"
                  "🟪 باقات بنك MOX الرقمي\n"
                  "تُطرح أسعار الباقات كنسبة من وحدة MOX النمطية MDU، ويمكن معرفة القيمة النقدية المباشرة من متجر MOX داخل التطبيق.\n\n"
                  "🔹 باقة المديدة | Al-Madida Package (السعر: 4%):\n"
                  "بطاقة رقمية واحدة داخل مول MOX، عرض منتج أو خدمة أو لافتة، الوجود ضمن رابط واحد يديره الوكيل مباشرة، حرية التصفح، رقم MOX عادي. التجديد السنوي: 5%.\n\n"
                  "🔹 باقة الجنية الرابح | The Winning Fairy Package (السعر: 10%):\n"
                  "مناسبة للدكان، المتجر، البوتيك، الكوافير، أو أي نشاط تجاري آخر. تمنح موقعًا/متجرًا رقميًا داخل MOX، ورقم MOX عادي. التجديد السنوي: 5%.\n\n"
                  "🔹 باقة اللوكس المتقدمة | Advanced Luxe Package (السعر: 21%):\n"
                  "مخصصة للأعمال والأنشطة المهنية المتقدمة (عيادة، مكتب محاماة، عقارات، شركة، منظومة...). تمنح حضورًا رقميًا احترافيًا، ورقم MOX مميز. التجديد السنوي: 5%.\n\n"
                  "🔹 باقة الهبّابة VIP | Al-Habbaba VIP Package (السعر: 32%):\n"
                  "الباقة الأعلى في منظومة MOX، تجمع مزايا الباقات المتقدمة وتحصل من خلالها على سجل وكيل، سجل إنشاء حساب فرد ومؤسسة، سجل استثماري، ورقم MOX مميز. التجديد السنوي: 5%.\n\n"
                  "🔸 باقة المساعد التقني | Technical Assistant Package:\n"
                  "مخصصة لمن يريد أن تقوم MOX بمساعدته في تجهيز حضوره الرقمي (تجهيز الحساب، المتجر، المكتب، وتنفيذ الإعدادات). رسوم المساعد التقني: سعر الباقة + 5%. كما يمكن شراء أي باقة بنظام التقسيط لمدة 4 أشهر: سعر الباقة + 7%.\n\n"
                  "📒 طريقة استخدام بنك MOX الرقمي\n"
                  "1️⃣ سجّل بياناتك: ابدأ بإنشاء حسابك وإدخال بياناتك.\n"
                  "2️⃣ استفد من منظومة نقاط MOX: أخبر الآخرين عن التطبيق، وعند تسجيل عميل جديد، امنحه رقم MOX الخاص بك ليقوم بإدراجه في خانة الوصي.\n"
                  "3️⃣ لديك نظامان للدخول: الحسابات المجانية برقم الهاتف، والحسابات الاحترافية برقم MOX.\n"
                  "4️⃣ أنشئ أصولك الرقمية: من قسم أصول العميل الرقمية يمكنك بناء دكانك أو متجرك خلال دقائق.\n"
                  "5️⃣ استكشف متجر MOX: للاطلاع على الباقات، المنتجات، والأسعار.\n\n"
                  "🚀 MOX… ابدأ صغيرًا، وابنِ عالمك الرقمي\n"
                  "لا تحتاج إلى أن تبدأ برأس مال كبير. ابدأ بحساب مجاني، استكشف المنظومة، وامتلك رقم MOX عندما تكون جاهزًا. ثم ابنِ موقعك، وطوّر حضورك الرقمي، واستفد من الخدمات والبرامج التي توفرها المنظومة.\n\n"
                  "MOX ليست مجرد مكان لعرض منتجك…\n"
                  "MOX هي مساحة لبناء هويتك الرقمية.\n\n"
                  "✍️ المنظومة أونلاين | MOX\n"
                  "🤚 المنظومة أونلاين MOX عقل الدولة القادمة",
              color: const Color.fromRGBO(243, 229, 245, 1),
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
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15, // تم ضبط الحجم ليكون واضحاً كعنوان للبطاقة
            color: Color(0xFF2C3E50), // عنوان غامق وبارز
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 13, // حجم مريح للقراءة داخل القائمة المنسدلة
                color: Color(0xFF1A1A1A), // أسود غامق وصريح وغير باهت
                height: 1.5, // مسافة مريحة جداً بين الأسطر
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
        widget.user.guardianMoxId!.isNotEmpty &&
        widget.user.guardianMoxId != "لم يحدد";

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
                      "📦 المنتجات الرقمية:",
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
                            "📂 تطبيقات الحاسوب )",
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
                            "⚙️ الخدمات الرقمية",
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

  // 📁 أصول العميل الرقمية ومتجره الإلكتروني
  // الوظيفة الحالية: فتح لوحة إدارة ونشر المتجر فقط.
  // البطاقات لم تعد تُدار من هنا.
  void _showClientAssetsScreen(BuildContext context) {
    // الهوية المعتمدة لرابط العميل:
    // guardianMoxId هو المعرف اليدوي الذي يحدد رابط المتجر.
    // moxId هو المعرف التلقائي ولا يُستخدم لبناء رابط المتجر.
    final String directMoxId =
        (widget.user.guardianMoxId?.trim().isNotEmpty == true)
        ? widget.user.guardianMoxId!.trim()
        : widget.user.moxId.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctxModal) {
        return Container(
          padding: const EdgeInsets.all(24),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس النافذة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF28A9CC),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "📁 بوابة أصول العميل الرقمية",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6B80),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctxModal),
                  ),
                ],
              ),

              const Divider(height: 25, thickness: 1.2),

              // بطاقة المتجر
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF28A9CC), Color(0xFF1B6B80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF28A9CC).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "مرحباً بك، ${widget.user.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "من هنا يمكنك الدخول مباشرة إلى لوحة إعداد ونشر متجرك السيادي.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // فتح لوحة إدارة المتجر
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A9CC),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctxModal);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientStoreAdminScreen(
                          user: widget.user,

                          // لم تعد أصول العميل مسؤولة عن البطاقات.
                          // نرسل قائمة فارغة فقط للمحافظة على توافق
                          // Constructor الحالي للصفحة A.
                          clientCards: const [],

                          // الرابط يعتمد على guardianMoxId أولاً.
                          directMoxId: directMoxId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text(
                    "فتح لوحة إعداد ونشر المتجر",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
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
                "يمكنك تعديل بياناتك الشخصية :",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 15),
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
  late UserModel _currentUser;
  late List<String> _alerts;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _updateAlerts();
    _refreshUserData();
  }

  void _updateAlerts() {
    _alerts = [
      "🚨 تنبيه MOX: لديك ${_currentUser.points} نقطة مكتسبة في شبكة الإحالة السيادية.",
      _currentUser.guardianMoxId!.isNotEmpty
          ? "🌟 تم تفعيل هويتك الرقمية برقم MOX: ${_currentUser.guardianMoxId}"
          : "⚠️ حسابك لم يُرقَّ بعد، شارك رابط الترقية لتوثيق أصولك.",
      "📌 متجر موكس جاهز لاستقبال طلبات بطاقات العرض والخدمات الرقمية.",
      "🏛️ المنظومة أونلاين: تأكد من تحديث وسائط التواصل لضمان تدفق الأرباح والأصول.",
    ];
  }

  Future<void> _refreshUserData() async {
    await StorageService.ensureLoaded();
    final freshUser = await StorageService.getUserByMoxId(_currentUser.moxId);
    if (freshUser != null && mounted) {
      setState(() {
        _currentUser = freshUser;
        _updateAlerts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  tooltip: "التنبيه التالي وتحديث البيانات",
                  onPressed: () {
                    setState(() {
                      _currentIndex = (_currentIndex + 1) % _alerts.length;
                    });
                    _refreshUserData();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
