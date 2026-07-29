import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

class StoreOrdersScreen extends StatefulWidget {
  final UserModel currentUser;
  const StoreOrdersScreen({super.key, required this.currentUser});

  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen> {
  final _formKey = GlobalKey<FormState>();

  // حقول الاستمارة
  late final TextEditingController _nameController;
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _requestDetailsController =
      TextEditingController();

  // المؤسسة
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _orgActivityController = TextEditingController();

  String _requestType = "استشارة"; // استشارة، منتج رقمي
  String _entityType = "فرد"; // فرد، مؤسسة

  // شروط الفرد
  String _hasMoxProduct = "لا"; // نعم / لا
  String _wantsMoxProduct = "نعم"; // نعم / لا

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _whatsappController.text = widget.currentUser.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _requestDetailsController.dispose();
    _orgNameController.dispose();
    _orgActivityController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_formKey.currentState!.validate()) {
      final String currentDate = DateTime.now().toString().substring(0, 10);

      // تجهيز نص الرسالة المراد إرسالها إلى الواتساب مع نسخ البيانات المدرجة
      final String whatsappMessage =
          '''
📦 *طلب جديد من متجر موكس الرقمي*
--------------------------------
👤 *الاسم:* ${_nameController.text}
📅 *التاريخ:* $currentDate
📌 *نوع الطلب:* $_requestType
📱 *رقم الواتس:* ${_whatsappController.text}
🏢 *نوع الكيان:* $_entityType
${_entityType == "فرد" ? "▫️ تمتلك منتج موكس؟: $_hasMoxProduct\n▫️ ترغب بامتلاك منتج؟: $_wantsMoxProduct" : "▫️ اسم المؤسسة: ${_orgNameController.text}\n▫️ نوع النشاط: ${_orgActivityController.text}"}
--------------------------------
📝 *نص الطلب:*
${_requestDetailsController.text}
''';

      // رقم الواتساب المطلوب للإرسال (تم إزالة const لتفادي خطأ الـ Compiler)
      final String targetWhatsAppUrl =
          "https://wa.me/249115855164?text=${Uri.encodeComponent(whatsappMessage)}";

      final Uri uri = Uri.parse(targetWhatsAppUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // إظهار رسالة النجاح الفاخرة
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 30,
                height: 30,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.verified, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              const Text(
                "تم استلام طلبك بنجاح",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          content: const Text(
            "أهلاً بك. نرحب برسالتك ونفيدك بأن الرد سوف يصله في الواتس..\n\nمع التنبيه إذا تأخر الرد ٧٢ ساعة.. سارع بمراجعة طلبك عبر واتس إدارة الأنظمة و المبيعات 249115855164",
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A9CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // إغلاق الحوار
                  Navigator.pop(context); // العودة للشاشة السابقة
                },
                child: const Text(
                  "حسناً، شكراً لك",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentDate = DateTime.now().toString().substring(0, 10);
    const Color moxBlue = Color(0xFF28A9CC);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "طلبيات متجر موكس",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // اللوقو في الأعلى
                  CircleAvatar(
                    backgroundColor: moxBlue.withValues(alpha: 0.1),
                    radius: 35,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.store, color: moxBlue, size: 35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "استمارة طلبات متجر موكس الرقمي",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Divider(height: 30),

                  // الاسم (تلقائي ولا يعدل)
                  TextFormField(
                    controller: _nameController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "الاسم (اسم العميل)",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // التاريخ (تلقائي ولا يعدل)
                  TextFormField(
                    initialValue: currentDate,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "التاريخ",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // موضوع الطلب / نوع الطلب
                  DropdownButtonFormField<String>(
                    initialValue: _requestType,
                    decoration: const InputDecoration(
                      labelText: "نوع الطلب",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "استشارة",
                        child: Text("استشارة"),
                      ),
                      DropdownMenuItem(
                        value: "منتج رقمي",
                        child: Text("منتج رقمي"),
                      ),
                    ],
                    onChanged: (val) => setState(() => _requestType = val!),
                  ),
                  const SizedBox(height: 15),

                  // رقم الواتس
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "رقم الواتس",
                      hintText: "249xxxxxxxx",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "الرجاء إدخال رقم الواتس" : null,
                  ),
                  const SizedBox(height: 15),

                  // هل أنت فرد أم مؤسسة
                  DropdownButtonFormField<String>(
                    initialValue: _entityType,
                    decoration: const InputDecoration(
                      labelText: "هل أنت فرد أم مؤسسة",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: "فرد", child: Text("فرد")),
                      DropdownMenuItem(value: "مؤسسة", child: Text("مؤسسة")),
                    ],
                    onChanged: (val) => setState(() => _entityType = val!),
                  ),
                  const SizedBox(height: 15),

                  // الشروط بناءً على الاختيار
                  if (_entityType == "فرد") ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _hasMoxProduct,
                            decoration: const InputDecoration(
                              labelText: "هل تمتلك منتج رقمي من موكس؟",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "نعم",
                                child: Text("نعم"),
                              ),
                              DropdownMenuItem(value: "لا", child: Text("لا")),
                            ],
                            onChanged: (val) =>
                                setState(() => _hasMoxProduct = val!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _wantsMoxProduct,
                            decoration: const InputDecoration(
                              labelText: "هل ترغب في إمتلاك منتج رقمي من موكس؟",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: "نعم",
                                child: Text("نعم"),
                              ),
                              DropdownMenuItem(value: "لا", child: Text("لا")),
                            ],
                            onChanged: (val) =>
                                setState(() => _wantsMoxProduct = val!),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _orgNameController,
                            decoration: const InputDecoration(
                              labelText: "اسم المؤسسة",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) =>
                                _entityType == "مؤسسة" && v!.isEmpty
                                ? "الرجاء إدخال اسم المؤسسة"
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _orgActivityController,
                            decoration: const InputDecoration(
                              labelText: "نوع النشاط",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) =>
                                _entityType == "مؤسسة" && v!.isEmpty
                                ? "الرجاء إدخال نوع النشاط"
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),

                  // نص الطلب (بحد أقصى ١٦٥ حرف)
                  TextFormField(
                    controller: _requestDetailsController,
                    maxLength: 165,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "نص الطلب (حد أقصى 165 حرف)",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "الرجاء كتابة نص الطلب" : null,
                  ),
                  const SizedBox(height: 20),

                  // زر إرسال الطلب
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxBlue,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _submitOrder,
                    child: const Text(
                      "أرسل طلبك الآن عبر الواتساب",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
