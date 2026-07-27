import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

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
  late TextEditingController _guardianController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    // حقل رقم الوصي (الذي أرشده) مع القيمة الافتراضية السيادية للمدير
    _guardianController = TextEditingController(
      text: widget.user.guardianMoxId ?? "MOX249-00010001",
    );
  }

  // دالة الواتساب النظيفة الخالية من أي كود ميت بالمسطرة
  Future<void> _launchWhatsApp(String phone, String message) async {
    final Uri url = Uri.parse(
      "https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من نوع الحساب بناءً على الثلاثي السيادي (مجاني، محترف، وكيل)
    String accountType = widget.user.accountType;
    bool isFree = accountType == 'مجاني';
    bool isAgent = accountType == 'وكيل';

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
            const SizedBox(height: 20),

            // حقول التعديل
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

            // بطاقة رقم الوصي (الإضافة القنبلة)
            TextField(
              controller: _guardianController,
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
                  "مرحباً.. أريد الاستفسار عن خدمات الحساب المحترف في MOX",
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
                  "أريد ترقية حسابي من مجاني إلى محترف في بنك MOX",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "ترقية الحساب الآن",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم حفظ التغييرات في السجل السيادي"),
                  ),
                );
              },
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
