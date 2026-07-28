import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import '../models/user_model.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;
  const ClientStoreAdminScreen({super.key, required this.user});

  @override
  State<ClientStoreAdminScreen> createState() => _ClientStoreAdminScreenState();
}

class _ClientStoreAdminScreenState extends State<ClientStoreAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  // حقول الدكان والمتجر
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _businessCategoryController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // قوائم منسدلة للـ 5 بطاقات (تخزين البطاقات المختارة)
  final List<String?> _selectedCards = List.filled(5, null);

  // قائمة البطاقات الوهمية المتاحة للاختيار (أو أصول النظام)
  final List<String> _availableCardsPool = [
    'بطاقة/رف - 1: التمويل الرقمي الذكي',
    'بطاقة/رف - 2: خدمات التوثيق السيادي',
    'بطاقة/رف - 3: المتجر المالي المفتوح',
    'بطاقة/رف - 4: خدمات الاستشارات الرقمية',
    'بطاقة/رف - 5: بوابة الدفع والاعتماد',
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone;
  }

  // فحص أمني صارم لدخول الصفحة A
  bool _checkStrictAccess() {
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

    return hasValidMoxAccess;
  }

  void _publishStore() {
    if (!_checkStrictAccess()) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad, color: Colors.red),
              SizedBox(width: 8),
              Text(
                "خطأ أمني فاخر",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: const Text(
            "عفواً، وصول مرفوض. يتطلب الدخول لهذه اللوحة امتلاك رقم MOX سيادي معتمد وصحيح.",
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28A9CC),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("حسناً", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // تنفيذ أمر النشر التلقائي لمدة 365 يوماً
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🚀 تم نشر الدكان والمتجر بنجاح تلقائياً لمدة 365 يوماً",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: const Text(
          "لوحة إعداد ونشر الدكان (الصفحة A)",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "🛒 إعدادات المتجر السيادي وإدارة الـ 5 رفوف",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),

              // ١- اسم الدكان/المتجر
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: "١- اسم الدكان/المتجر",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "يرجى إدخال اسم الدكان" : null,
              ),
              const SizedBox(height: 15),

              // ٢- المجال التجاري
              TextFormField(
                controller: _businessCategoryController,
                decoration: const InputDecoration(
                  labelText: "٢- المجال التجاري",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? "يرجى تحديد المجال التجاري"
                    : null,
              ),
              const SizedBox(height: 15),

              // ٤- هاتف اتصال
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "٤- هاتف اتصال",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => val == null || val.length < 10
                    ? "يرجى إدخال هاتف صحيح"
                    : null,
              ),
              const SizedBox(height: 15),

              // ٥- وصف (في حدود ٢٥٦ حرف)
              TextFormField(
                controller: _descriptionController,
                maxLength: 256,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "٥- وصف المتجر (في حدود ٢٥٦ حرف)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "يرجى كتابة وصف موجز" : null,
              ),
              const SizedBox(height: 15),

              const Text(
                "٦ & ٧- قوائم البطاقات الـ 5 (بطاقة/رف)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),

              // تكرار القائمة المنسدلة 5 مرات
              ...List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCards[index],
                    decoration: InputDecoration(
                      labelText: "بطاقة/رف - ${index + 1}",
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _availableCardsPool.map((cardTitle) {
                      return DropdownMenuItem(
                        value: cardTitle,
                        child: Text(
                          cardTitle,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCards[index] = val;
                      });
                    },
                    validator: (val) =>
                        val == null ? "يرجى اختيار محتوى لهذا الرف" : null,
                  ),
                );
              }),

              const SizedBox(height: 30),

              // ٨- زر نشر الدكان/المتجر (٣٦٥ يوم تلقائي)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A9CC),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _publishStore,
                icon: const Icon(Icons.verified_rounded, color: Colors.white),
                label: const Text(
                  "نشر الدكان/المتجر (365 يوم تلقائياً)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
