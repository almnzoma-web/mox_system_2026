import 'package:flutter/material.dart';
import '../models/user_model.dart';
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
  final TextEditingController _guardianController = TextEditingController();

  String _selectedGender = "ذكر";
  String _selectedAccountType = "فردي";
  bool _isPasswordVisible = false;

  // 🔢 دالة توليد الترقيم التلقائي بدقة متناهية لمنع التكرار وتصاعد الأرقام ابتداءً من 5001
  Future<String> _generateSequentialMoxId() async {
    await StorageService.ensureLoaded();

    int nextNumber = 5001; // يبدأ العملاء من 5001 فصاعداً بعد المدير 5000

    if (StorageService.registeredUsers.isNotEmpty) {
      List<int> existingNumbers = [];
      for (var user in StorageService.registeredUsers) {
        if (user.moxId.startsWith("ID-")) {
          String numericPart = user.moxId.replaceFirst("ID-", "");
          int? parsedVal = int.tryParse(numericPart);
          if (parsedVal != null && parsedVal >= 5000) {
            existingNumbers.add(parsedVal);
          }
        }
      }

      if (existingNumbers.isNotEmpty) {
        existingNumbers.sort();
        nextNumber = existingNumbers.last + 1;
      }
    }

    String formattedNum = nextNumber.toString().padLeft(6, '0');
    return "ID-$formattedNum";
  }

  // ⏳ عرض مؤشر الانتظار الفاخر في منتصف الشاشة أثناء الربط السحابي بقوقل
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: moxBlue),
                const SizedBox(width: 20),
                const Expanded(
                  child: Text(
                    "جاري اعتمادك في بنك موكس...",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _register() async {
    String phoneInput = _phoneController.text.trim();

    // التحقق بالمسطرة من أن رقم الهاتف يبدأ بـ 249 ويتكون من 12 رقماً
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

    // إظهار رسالة الانتظار الفاخرة أثناء المعالجة والتسجيل السحابي
    _showLoadingDialog();

    // توليد الترقيم التلقائي الصحيح والمضمون للعميل
    String newMoxId = await _generateSequentialMoxId();

    // معالجة رقم الوصي: إذا ترك فارغاً يعتمد النظام للمدير حصرياً (MOX249-00010001)
    String inputGuardian = _guardianController.text.trim();
    String finalGuardianId = inputGuardian.isEmpty
        ? "MOX249-00010001"
        : inputGuardian;

    final newUser = UserModel(
      phone: phoneInput,
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      moxId: newMoxId, // الهوية الرقمية الفريدة للعميل حصرياً
      address: _addressController.text.trim(),
      balance: 0.0,
      gender: _selectedGender,
      accountType: _selectedAccountType,
      role: "user",
      guardianMoxId: finalGuardianId, // حقل الوصي المحدث (المدير افتراضياً)
      points: 0,
      myAssets: [],
    );

    // إضافة العميل وترحيله السحابي مع تحديث نقاط الوصي إن وجد
    await _addUserWithReferral(newUser, finalGuardianId);

    // إغلاق مؤشر الانتظار الفاخر
    if (mounted) {
      Navigator.pop(context); // إغلاق الـ Loading Dialog
      _showSovereignCertificate(newUser, newMoxId); // إظهار شهادة الاعتماد
    }
  }

  Future<void> _addUserWithReferral(
    UserModel newUser,
    String guardianId,
  ) async {
    await StorageService.ensureLoaded();

    if (!StorageService.registeredUsers.any((u) => u.moxId == newUser.moxId)) {
      if (guardianId.isNotEmpty) {
        int guardianIndex = StorageService.registeredUsers.indexWhere(
          (u) => u.moxId == guardianId,
        );

        if (guardianIndex != -1) {
          var guardian = StorageService.registeredUsers[guardianIndex];
          StorageService.registeredUsers[guardianIndex] = UserModel(
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
            points:
                guardian.points + 100, // منح 100 نقطة للوصي الحقيقي أو المدير
            myAssets: guardian.myAssets,
          );
        }
      }

      // حفظ العميل الجديد في الشيت والسحاب والمحلي فوراً
      await StorageService.addUser(newUser);
      debugPrint(
        "➕ [Storage] تم تسجيل المواطن بنجاح وترحيله إلى قاعدة بيانات قوقل.",
      );
    }
  }

  void _showSovereignCertificate(UserModel registeredUser, String moxId) {
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
            constraints: const BoxConstraints(maxHeight: 550),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: moxBlue, width: 3),
            ),
            child: SingleChildScrollView(
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

            // بطاقة الوصي الاحترافية (اختيارية: تعتمد المدير افتراضياً إذا تركت خالية)
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
                    "إذا أخبرك عميل عن موكس، الرجاء وضع رقم موكس الخاص به. وإذا تركته فارغاً، فسيعتمد النظام رقم مرشد المدير (MOX249-00010001) تلقائياً كوصي لك.",
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
                      labelText: "رقم MOX للوصي (اختياري - افتراضياً المدير)",
                      hintText: "MOX249-00010001",
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
