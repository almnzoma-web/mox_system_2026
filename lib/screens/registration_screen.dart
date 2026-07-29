import 'package:flutter/material.dart';
import '../models/user_model.dart';
// ربط الخزينة المركزية لضمان الاعتماد المباشر لدالة الإضافة
import '../data/user_data.dart';
// ربط خدمة التخزين السيادية لضمان الحفظ الفوري الدائم
import '../services/storage_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final Color moxBlue = const Color(0xFF28A9CC);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _guardianController =
      TextEditingController(); // حقل الوصي الاختياري

  String _selectedGender = "ذكر";
  String _selectedAccountType = "فردي";
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    String phoneInput = _phoneController.text.trim();

    // التحقق بالمسطرة من أن رقم الهاتف يبدأ بـ 249 ويتكون من 12 رقماً تماماً دون أي تكرار
    bool isPhoneValid = RegExp(r'^249\d{9}$').hasMatch(phoneInput);

    if (_nameController.text.trim().isEmpty || !isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ يرجى إدخال الاسم كاملاً، ورقم الهاتف بالصيغة الصحيحة (249 تبدأ بـ وتتكون من 12 رقماً).",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String newMoxId = "MOX${timestamp.substring(timestamp.length - 8)}";

    // معالجة رقم الوصي (المرشد): إذا ترك فارغاً أو خطأ، يُسند تلقائياً للمدير السيادي
    String inputGuardian = _guardianController.text.trim();
    String finalGuardianId = inputGuardian.isEmpty
        ? "MOX249-00010001"
        : inputGuardian;

    // حفظ رقم الهاتف كما كتبه المستخدم تماماً
    final newUser = UserModel(
      phone: phoneInput,
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      moxId: newMoxId,
      address: _addressController.text.trim(),
      balance: 0.0,
      gender: _selectedGender,
      accountType: _selectedAccountType,
      role: "user",
      guardianMoxId: finalGuardianId, // ربط الوصي بالبيانات
      points: 0,
    );

    // إضافة العميل وتحديث نقاط الوصي وتثبيته في الذاكرة الدائمة عبر الخزينة وStorageService
    await addUserWithReferral(newUser, finalGuardianId);

    if (mounted) {
      _showSovereignCertificate(newMoxId);
    }
  }

  // دالة مخصصة لإضافة العميل وتحديث نقاط الوصي بالمسطرة والحفظ الدائم
  Future<void> addUserWithReferral(UserModel newUser, String guardianId) async {
    // ضمان تحميل السجلات السيادية أولاً لمنع أي فراغ
    await StorageService.ensureLoaded();
    await ensureLoaded();

    // البحث عن الوصي في السجل لمنحه 100 نقطة
    int guardianIndex = registeredUsers.indexWhere(
      (u) => u.moxId.trim().toUpperCase() == guardianId.trim().toUpperCase(),
    );

    if (guardianIndex != -1) {
      var guardian = registeredUsers[guardianIndex];
      registeredUsers[guardianIndex] = UserModel(
        phone: guardian.phone,
        password: guardian.password,
        name: guardian.name,
        address: guardian.address,
        balance: guardian.balance,
        commission: guardian.commission,
        gender: guardian.gender,
        accountType: guardian.accountType,
        moxId: guardian.moxId,
        role: guardian.role,
        customWhatsApp: guardian.customWhatsApp,
        guardianMoxId: guardian.guardianMoxId,
        points: guardian.points + 100, // إضافة 100 نقطة تلقائياً للوصي
        myAssets: guardian.myAssets,
      );
      debugPrint(
        "🎯 [Referral] تم منح 100 نقطة للوصي: ${guardian.name} (${guardian.moxId})",
      );
    } else {
      // إذا كان رقم الوصي خطأ تماماً، تذهب الـ 100 نقطة للمدير كصمام أمان سيادي
      int adminIndex = registeredUsers.indexWhere(
        (u) => u.moxId == "MOX249-00010001",
      );
      if (adminIndex != -1) {
        var admin = registeredUsers[adminIndex];
        registeredUsers[adminIndex] = UserModel(
          phone: admin.phone,
          password: admin.password,
          name: admin.name,
          address: admin.address,
          balance: admin.balance,
          commission: admin.commission,
          gender: admin.gender,
          accountType: admin.accountType,
          moxId: admin.moxId,
          role: admin.role,
          customWhatsApp: admin.customWhatsApp,
          guardianMoxId: admin.guardianMoxId,
          points: admin.points + 100,
          myAssets: admin.myAssets,
        );
      }
    }

    // إدراج العميل الجديد وحفظه قطعيًا عبر دالة الخزينة المعتمدة
    await addUser(newUser);
    await StorageService.saveUsersList();

    debugPrint(
      "➕ [Data] تم تسجيل المواطن بنجاح وحفظه للأبد في الذاكرة الدائمة.",
    );
  }

  void _showSovereignCertificate(String moxId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "شهادة اعتماد",
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 550,
            ), // تقييد الارتفاع لمنع الخروج عن الشاشة
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: moxBlue, width: 3),
            ),
            child: SingleChildScrollView(
              // السماح بالتمرير برطوبة وسلاسة التامة
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user,
                    color: Color(0xFF28A9CC),
                    size: 70,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "شهادة اعتماد سيادية",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28A9CC),
                    ),
                  ),
                  const Divider(
                    thickness: 2,
                    color: Colors.black12,
                    height: 25,
                  ),
                  Text(
                    "تم اعتمادك في بنك موكس الرقمي بنجاح.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "كود الهوية الرقمية:\n$moxId",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "هذا الكود هو مفتاحك لامتلاك رقم موكس الخاص عند ترقية حسابك في الدولة الرقمية السيادية.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxBlue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "استمرار",
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "تسجيل عميل سيادي",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(
              Icons.account_circle,
              size: 80,
              color: Color(0xFF28A9CC),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "الاسم الكامل",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
                hintText: "249xxxxxxxxx",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "كلمة السر",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "العنوان",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 20),

            // بطاقة الوصي الاحترافية (اختيارية مع الشرح السيادي)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moxBlue.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "💡 بطاقة الوصي أو المرشد (اختياري)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF28A9CC),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "إذا أخبرك عميل عن موكس، الرجاء وضع رقم موكس الخاص به إذا كنت تعرف رقمه، وإذا لا تعرفه، اترك هذا الحقل خالي.. يمكنك الاستفادة من رصيد النقاط بجلب عملاء وتمنحهم رقمك الخاص في موكس الذي تتحصل عليه بعد أن تقوم بترقية حسابك.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guardianController,
                    decoration: const InputDecoration(
                      labelText: "رقم MOX للوصي (اختياري)",
                      hintText: "MOX249-XXXXXXXX",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.supervised_user_circle,
                        color: Color(0xFF28A9CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              items: [
                "ذكر",
                "أنثى",
              ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v!),
              decoration: const InputDecoration(
                labelText: "الجنس",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountType,
              items: [
                "فردي",
                "تجاري",
              ].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: (v) => setState(() => _selectedAccountType = v!),
              decoration: const InputDecoration(
                labelText: "نوع الحساب",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: moxBlue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _register,
              child: const Text(
                "إتمام التسجيل السيادي",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "جميع الحقوق محفوظة ©️ المنظومة أونلاين موكس ${DateTime.now().year}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
