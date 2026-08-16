import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color moxBlue = const Color(0xFF33A1C9);
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _guardianMoxIdController;
  late TextEditingController _guardianMoxIdCustomerController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    _guardianMoxIdController = TextEditingController(
      text: widget.user.guardianMoxId ?? "MOX249-xxxxxxxx",
    );
    _guardianMoxIdCustomerController = TextEditingController(
      text: widget.user.guardianMoxIdCustomer ?? "MOX249-00010001",
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _guardianMoxIdController.dispose();
    _guardianMoxIdCustomerController.dispose();
    super.dispose();
  }

  // دالة الواتساب النظيفة
  Future<void> _launchWhatsApp(String phone, String message) async {
    final Uri url = Uri.parse(
      "https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // دالة حساب صلاحية المتجر (365 يوم من تاريخ التفعيل/التسجيل)
  Map<String, dynamic> _calculateStoreSubscription() {
    // نفترض أن UserModel يحتوي على حقل تاريخ التفعيل أو نستخدم تاريخ حالي افتراضي إذا لم يوجد
    // يمكنك ربطها لاحقاً بـ widget.user.activationDate إذا أردت
    DateTime activationDate;
    try {
      activationDate = widget.user.activationDate != null
          ? DateTime.parse(widget.user.activationDate!)
          : DateTime.now();
    } catch (_) {
      activationDate = DateTime.now();
    }

    DateTime expiryDate = activationDate.add(const Duration(days: 365));
    int remainingDays = expiryDate.difference(DateTime.now()).inDays;
    bool isExpired = remainingDays <= 0;

    return {
      'expiryDate':
          "${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
      'remainingDays': isExpired ? 0 : remainingDays,
      'isExpired': isExpired,
    };
  }

  // دالة الحفظ السيادية (تحديث محلي + رفع فوري لشيت قوقل)
  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. تحديث بيانات الكائن بالقيم الجديدة بالمسطرة
      widget.user.name = _nameController.text.trim();
      widget.user.phone = _phoneController.text.trim();
      widget.user.address = _addressController.text.trim();
      widget.user.guardianMoxId = _guardianMoxIdController.text.trim();

      // 2. إرسال البيانات للمنظومة (المحلي + السحابي في شيت Users)
      await StorageService.addUser(widget.user);
      await StorageService.saveUser(widget.user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حفظ التغييرات ورفعها لشيت قوقل بنجاح بالمسطرة!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء الحفظ: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String accountType = widget.user.accountType;
    bool isFree = accountType == 'مجاني';
    bool isAgent = accountType == 'وكيل';

    // فحص فترة الـ 365 يوم للمتجر
    final subInfo = _calculateStoreSubscription();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "الملف الشخصي السيادي",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // بطاقة المعلومات السيادية للمواطن
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: ListTile(
                  title: Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("الهوية: ${widget.user.moxId}"),
                      Text("نوع الحساب: $accountType"),
                      const SizedBox(height: 5),
                      Text(
                        "الرصيد: ${widget.user.balance} | النقاط: ${widget.user.points}",
                        style: const TextStyle(
                          color: Color(0xFF28A9CC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: moxBlue,
                    radius: 30,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // بطاقة فحص فترة صلاحية المتجر (365 يوم)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: subInfo['isExpired']
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: subInfo['isExpired'] ? Colors.red : Colors.teal,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    subInfo['isExpired']
                        ? Icons.warning_amber_rounded
                        : Icons.verified,
                    color: subInfo['isExpired'] ? Colors.red : Colors.teal,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "صلاحية المتجر الرقمي (فترة 365 يوم)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subInfo['isExpired']
                              ? "⚠️ انتهت صلاحية المتجر! يرجى التجديد."
                              : "الأيام المتبقية: ${subInfo['remainingDays']} يوماً (ينتهي في ${subInfo['expiryDate']})",
                          style: TextStyle(
                            color: subInfo['isExpired']
                                ? Colors.red
                                : Colors.teal.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // حقول التعديل بالمسطرة
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "الهاتف",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "العنوان",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 15),

            // بطاقة رقم الوصي
            TextField(
              controller: _guardianMoxIdController,
              decoration: const InputDecoration(
                labelText: "رقم MOX للوصي (المرشد)",
                hintText: "MOX249-XXXXXXXX",
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.supervised_user_circle,
                  color: Color(0xFF28A9CC),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // توجيه الأزرار بناءً على نوع الحساب
            if (isAgent) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  "حساب وكيل معتمد - صلاحيات سيادية كاملة بالمنظومة",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (!isFree) ...[
              ElevatedButton.icon(
                onPressed: () => _launchWhatsApp(
                  "249115855164",
                  "مرحباً.. أريد الاستفسار عن خدمات الحساب المحترف وتجديد متجر MOX",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: moxBlue,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  "الانتقال للواتساب الخاص بالمحترفين",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => _launchWhatsApp(
                  "249115855164",
                  "أريد ترقية حسابي وتفعيل متجري لمدة 365 يوم في بنك MOX",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "ترقية الحساب وتفعيل المتجر الآن",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            // زر الحفظ الفعلي المربوط بالمنظومة والسحابة
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "حفظ التغييرات",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
