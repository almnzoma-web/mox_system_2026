import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import '../models/user_model.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;
  final List<Map<String, dynamic>> clientCards;
  const ClientStoreAdminScreen({
    super.key,
    required this.user,
    required this.clientCards,
  });

  @override
  State<ClientStoreAdminScreen> createState() => _ClientStoreAdminScreenState();
}

class _ClientStoreAdminScreenState extends State<ClientStoreAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _businessCategoryController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late List<String?> _selectedCards;
  late List<String> _availableCardsPool;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone;

    _availableCardsPool = widget.clientCards
        .map((card) => card['title'].toString())
        .toList();
    _selectedCards = List.generate(
      5,
      (index) => index < _availableCardsPool.length
          ? _availableCardsPool[index]
          : null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSecurityLoginDialog();
    });
  }

  void _showSecurityLoginDialog() {
    final TextEditingController moxInputController = TextEditingController(
      text: widget.user.moxId != "لم يحدد" ? widget.user.moxId : "",
    );
    final TextEditingController passwordInputController =
        TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF28A9CC)),
            SizedBox(width: 8),
            Text(
              "التحقق الأمني السيادي",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "الرجاء إدخال رقم MOX السيادي وكلمة السر للمتابعة:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moxInputController,
              decoration: const InputDecoration(
                labelText: "رقم MOX",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordInputController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة السر",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A9CC),
            ),
            onPressed: () {
              String enteredMox = moxInputController.text.trim();

              bool isValid =
                  (enteredMox == widget.user.moxId ||
                  enteredMox == widget.user.guardianMoxId ||
                  enteredMox.isNotEmpty);

              Navigator.pop(ctx);
              if (!isValid) {
                _showLuxuryErrorDialog();
              }
            },
            child: const Text(
              "دخول سيادي",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLuxuryErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "خطأ أمني فاخر",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: const Text(
          "عفواً، وصول مرفوض. رقم MOX أو كلمة السر غير مطابقة.",
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
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("حسناً", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _publishStore() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🚀 تم نشر الدكان والمتجر وربط رابط العميل بنجاح تلقائياً لمدة 365 يوماً",
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
                "🛒 إعدادات المتجر السيادي وإدارة الـ 5 رفوف المستلمة",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),

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
                "٦ & ٧- ربط البطاقات الـ 5 المستلمة من الحفظ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),

              ...List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<String>(
                    // استخدام initialValue لتجنب تحذير value القديم
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
                  "نشر الدكان/المتجر وتوليد رابط العميل (365 يوم)",
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
