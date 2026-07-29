import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import '../models/user_model.dart';
// ربط خزينة البيانات السيادية لجلاستعلام الحسابات المسجلة
import '../data/user_data.dart';
// ربط خدمة التخزين لضمان التحميل الفوري وتحديث السجلات
import '../services/storage_service.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;
  final List<Map<String, dynamic>>
  clientCards; // استقبال الـ 5 بطاقات الحقيقية المعدلة
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

  bool _isAuthorized = false; // متغير لحراسة وجملة الأمان السيادي

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

    // إطلاق شاشة التحقق الأمني الفوري عبر الخزينة فور فتح الصفحة A
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSecurityLoginDialog();
    });
  }

  // نافذة التحقق الأمني المرتبطة بـ guardianMoxId المدفوع برسوم وكلمة السر بدقة
  void _showSecurityLoginDialog() async {
    // ضمان تحميل السجلات السيادية تماماً قبل فتح نافذة التحقق
    await StorageService.ensureLoaded();

    final TextEditingController guardianMoxInputController =
        TextEditingController(
          text:
              widget.user.guardianMoxId != null &&
                  widget.user.guardianMoxId!.isNotEmpty
              ? widget.user.guardianMoxId!
              : "MOX249-00010001",
        );
    final TextEditingController passwordInputController =
        TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Color(0xFF28A9CC)),
            SizedBox(width: 8),
            Text(
              "التحقق من رقم الوصي المدفوع (guardianMoxId)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "أدخل رقم الوصي المدفوع (guardianMoxId) مثل MOX249-00010001 وكلمة السر للمتابعة:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: guardianMoxInputController,
              decoration: const InputDecoration(
                labelText: "رقم الوصي (guardianMoxId)",
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
            onPressed: () async {
              String enteredGuardianMox = guardianMoxInputController.text
                  .trim();
              String enteredPassword = passwordInputController.text.trim();

              bool isValidFromStorage = false;
              try {
                // فحص دقيق ومطابقة مع guardianMoxId المسجل في الخزينة أو ملف العميل
                for (var u in registeredUsers) {
                  if (u.guardianMoxId != null &&
                      u.guardianMoxId!.trim().toUpperCase() ==
                          enteredGuardianMox.toUpperCase() &&
                      u.password == enteredPassword) {
                    isValidFromStorage = true;
                    break;
                  }
                }

                // مطابقة مباشرة مع العميل الحالي المرسل للشاشة
                if (!isValidFromStorage &&
                    widget.user.guardianMoxId != null &&
                    widget.user.guardianMoxId!.trim().toUpperCase() ==
                        enteredGuardianMox.toUpperCase() &&
                    widget.user.password == enteredPassword &&
                    enteredGuardianMox.isNotEmpty) {
                  isValidFromStorage = true;
                }
              } catch (_) {
                isValidFromStorage =
                    (widget.user.guardianMoxId != null &&
                    widget.user.guardianMoxId!.trim().toUpperCase() ==
                        enteredGuardianMox.toUpperCase() &&
                    widget.user.password == enteredPassword &&
                    enteredGuardianMox.isNotEmpty);
              }

              if (!mounted) return;
              Navigator.pop(ctx);

              if (!isValidFromStorage || enteredPassword.isEmpty) {
                setState(() {
                  _isAuthorized = false;
                });
                _showLuxuryErrorDialog();
              } else {
                setState(() {
                  _isAuthorized = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ تم التحقق من رقم الوصي (guardianMoxId) بنجاح - مرحباً بك",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              "تحقق معتمد",
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "خطأ في الاعتماد المالي والسيادي",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: const Text(
          "عفواً، وصول مرفوض. رقم الوصي (guardianMoxId) المدفوع برسوم أو كلمة السر غير مطابقة لما هو محفوظ في ملف العميل.",
          style: TextStyle(
            fontSize: 13,
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
    if (!_isAuthorized) {
      _showSecurityLoginDialog();
      return;
    }

    if (_formKey.currentState!.validate()) {
      bool hasAtLeastOneCard = _selectedCards.any(
        (card) => card != null && card.trim().isNotEmpty,
      );

      if (!hasAtLeastOneCard) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ تنبيه: يجب اختيار بطاقة واحدة على الأقل من الـ 5 بطاقات المتاحة لنشر المتجر!",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

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
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text(
            "منطقة مقفلة برهون الوصي",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            "جاري التحقق من رقم الوصي المدفوع (guardianMoxId)...",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: const Text(
          "لوحة النشر (الصفحة A)",
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
                "🛒 إعدادات المتجر السيادي وإدارة الـ 5 رفوف (يكفي اختيار بطاقة واحدة للنشر)",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: "١- اسم الدكان/المتجر (إلزامي)",
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
                  labelText: "٢- المجال التجاري (إلزامي)",
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
                  labelText: "٤- هاتف اتصال (إلزامي)",
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
                  labelText: "٥- وصف المتجر في حدود ٢٥٦ حرف (إلزامي)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "يرجى كتابة وصف موجز" : null,
              ),
              const SizedBox(height: 15),
              const Text(
                "٦ & ٧- ربط البطاقات (اختياري، شرط النشر اختيار بطاقة واحدة على الأقل)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCards[index],
                    decoration: InputDecoration(
                      labelText: "بطاقة/رف - ${index + 1} (اختياري)",
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          "-- فارغ (بدون بطاقة) --",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      ..._availableCardsPool.map((cardTitle) {
                        return DropdownMenuItem(
                          value: cardTitle,
                          child: Text(
                            cardTitle,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCards[index] = val;
                      });
                    },
                    validator: (val) => null,
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
                  "نشر الدكان والمتجر وتوليد رابط العميل (365 يوم)",
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
