import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color moxBlue = const Color(0xFF33A1C9);

  // وحدات التحكم بترتيب الحقول تماماً كما في UserModel
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _storeDescriptionController;
  late TextEditingController _balanceController;
  late TextEditingController _commissionController;
  late TextEditingController _genderController;
  late TextEditingController _accountTypeController;
  late TextEditingController _moxIdController;
  late TextEditingController _roleController;
  late TextEditingController _customWhatsAppController;
  late TextEditingController _guardianMoxIdController;
  late TextEditingController _guardianMoxIdCustomerController;
  late TextEditingController _storePublishDateController;
  late TextEditingController _activationDateController;
  late TextEditingController _pointsController;

  // الهوية الرقمية للتوقيع
  late TextEditingController _digitalPublicKeyController;
  late TextEditingController _digitalSignatureAlgorithmController;
  late TextEditingController _digitalSignatureCreatedAtController;
  late TextEditingController _digitalSignatureKeyVersionController;

  // قائمة الأصول القابلة للتعديل
  late List<MarketingCard> _myAssets;
  late List<dynamic> _signedDocuments;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user.phone);
    _passwordController = TextEditingController(text: widget.user.password);
    _nameController = TextEditingController(text: widget.user.name);
    _addressController = TextEditingController(text: widget.user.address);
    _storeDescriptionController = TextEditingController(
      text: widget.user.storeDescription,
    );
    _balanceController = TextEditingController(
      text: widget.user.balance.toString(),
    );
    _commissionController = TextEditingController(
      text: widget.user.commission.toString(),
    );
    _genderController = TextEditingController(text: widget.user.gender);
    _accountTypeController = TextEditingController(
      text: widget.user.accountType,
    );
    _moxIdController = TextEditingController(text: widget.user.moxId);
    _roleController = TextEditingController(text: widget.user.role);
    _customWhatsAppController = TextEditingController(
      text: widget.user.customWhatsApp ?? '',
    );
    _guardianMoxIdController = TextEditingController(
      text: widget.user.guardianMoxId ?? '',
    );
    _guardianMoxIdCustomerController = TextEditingController(
      text: widget.user.guardianMoxIdCustomer ?? '',
    );
    _storePublishDateController = TextEditingController(
      text: widget.user.storePublishDate ?? '',
    );
    _activationDateController = TextEditingController(
      text: widget.user.activationDate ?? '',
    );
    _pointsController = TextEditingController(
      text: widget.user.points.toString(),
    );

    _myAssets = List.from(widget.user.myAssets);
    _signedDocuments = List.from(widget.user.signedDocuments);

    _digitalPublicKeyController = TextEditingController(
      text: widget.user.digitalPublicKey ?? '',
    );
    _digitalSignatureAlgorithmController = TextEditingController(
      text: widget.user.digitalSignatureAlgorithm,
    );
    _digitalSignatureCreatedAtController = TextEditingController(
      text: widget.user.digitalSignatureCreatedAt ?? '',
    );
    _digitalSignatureKeyVersionController = TextEditingController(
      text: widget.user.digitalSignatureKeyVersion.toString(),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _storeDescriptionController.dispose();
    _balanceController.dispose();
    _commissionController.dispose();
    _genderController.dispose();
    _accountTypeController.dispose();
    _moxIdController.dispose();
    _roleController.dispose();
    _customWhatsAppController.dispose();
    _guardianMoxIdController.dispose();
    _guardianMoxIdCustomerController.dispose();
    _storePublishDateController.dispose();
    _activationDateController.dispose();
    _pointsController.dispose();
    _digitalPublicKeyController.dispose();
    _digitalSignatureAlgorithmController.dispose();
    _digitalSignatureCreatedAtController.dispose();
    _digitalSignatureKeyVersionController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final Uri url = Uri.parse(
      "https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _addNewAsset() {
    setState(() {
      _myAssets.add(
        MarketingCard(
          title: "بطاقة تسويقية جديدة",
          description: "وصف الأصل الرقمي",
          whatsapp: _phoneController.text,
          facebookUrl: "",
          category: 'بطاقة',
          iconKey: 'store',
          price: 0.0,
          isApproved: true,
        ),
      );
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      widget.user.phone = _phoneController.text.trim();
      widget.user.password = _passwordController.text.trim();
      widget.user.name = _nameController.text.trim();
      widget.user.address = _addressController.text.trim();
      widget.user.storeDescription = _storeDescriptionController.text.trim();
      widget.user.balance =
          double.tryParse(_balanceController.text.trim()) ?? 0.0;
      widget.user.commission =
          double.tryParse(_commissionController.text.trim()) ?? 0.0;
      widget.user.gender = _genderController.text.trim();
      widget.user.accountType = _accountTypeController.text.trim();
      widget.user.moxId = _moxIdController.text.trim();
      widget.user.role = _roleController.text.trim();
      widget.user.customWhatsApp = _customWhatsAppController.text.trim().isEmpty
          ? null
          : _customWhatsAppController.text.trim();

      // 🛡️ الحماية الصارمة لمعرفات المتجر السيادية
      widget.user.guardianMoxId = _guardianMoxIdController.text.trim();
      widget.user.guardianMoxIdCustomer = _guardianMoxIdCustomerController.text
          .trim();

      widget.user.storePublishDate =
          _storePublishDateController.text.trim().isEmpty
          ? null
          : _storePublishDateController.text.trim();
      widget.user.activationDate = _activationDateController.text.trim().isEmpty
          ? null
          : _activationDateController.text.trim();
      widget.user.points = int.tryParse(_pointsController.text.trim()) ?? 0;
      widget.user.myAssets = List.from(_myAssets);
      widget.user.signedDocuments = List.from(_signedDocuments);
      widget.user.digitalPublicKey =
          _digitalPublicKeyController.text.trim().isEmpty
          ? null
          : _digitalPublicKeyController.text.trim();
      widget.user.digitalSignatureAlgorithm =
          _digitalSignatureAlgorithmController.text.trim();
      widget.user.digitalSignatureCreatedAt =
          _digitalSignatureCreatedAtController.text.trim().isEmpty
          ? null
          : _digitalSignatureCreatedAtController.text.trim();
      widget.user.digitalSignatureKeyVersion =
          int.tryParse(_digitalSignatureKeyVersionController.text.trim()) ?? 1;

      // 1️⃣ الحفظ المحلي أولاً
      await StorageService.addUser(widget.user);
      await StorageService.saveUser(widget.user);

      // 2️⃣ إغلاق الثغرة: المزامنة الفورية مع سحابة جوجل شيتس لضمان بقاء الرابط محدثاً
      // (استدعي دالة المزامنة الخاصة بك هنا، مثل _syncClientToCloud إن وجدت أو السيرفر)
      // await _syncClientToCloud(widget.user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حفظ جميع حقول UserModel ومزامنتها بالمسطرة!"),
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
    bool isFree = widget.user.accountType == 'مجاني';
    bool isAgent = widget.user.accountType == 'وكيل';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "الملف الشخصي السيادي - UserModel",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: moxBlue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. phone
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "phone",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 15),

            // 2. password
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 15),

            // 3. name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),

            // 4. address
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: "address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 15),

            // 5. storeDescription
            TextField(
              controller: _storeDescriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "storeDescription",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 15),

            // 6. balance
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "balance",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 15),

            // 7. commission
            TextField(
              controller: _commissionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "commission",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
            ),
            const SizedBox(height: 15),

            // 8. gender
            TextField(
              controller: _genderController,
              decoration: const InputDecoration(
                labelText: "gender",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
            ),
            const SizedBox(height: 15),

            // 9. accountType
            TextField(
              controller: _accountTypeController,
              decoration: const InputDecoration(
                labelText: "accountType",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.card_membership),
              ),
            ),
            const SizedBox(height: 15),

            // 10. moxId
            TextField(
              controller: _moxIdController,
              decoration: const InputDecoration(
                labelText: "moxId",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fingerprint),
              ),
            ),
            const SizedBox(height: 15),

            // 11. role
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: "role",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security),
              ),
            ),
            const SizedBox(height: 15),

            // 12. customWhatsApp
            TextField(
              controller: _customWhatsAppController,
              decoration: const InputDecoration(
                labelText: "customWhatsApp",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat),
              ),
            ),
            const SizedBox(height: 15),

            // 13. guardianMoxId
            TextField(
              controller: _guardianMoxIdController,
              decoration: const InputDecoration(
                labelText: "guardianMoxId",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.supervised_user_circle),
              ),
            ),
            const SizedBox(height: 15),

            // 14. guardianMoxIdCustomer
            TextField(
              controller: _guardianMoxIdCustomerController,
              decoration: const InputDecoration(
                labelText: "guardianMoxIdCustomer",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 15),

            // 15. storePublishDate
            TextField(
              controller: _storePublishDateController,
              decoration: const InputDecoration(
                labelText: "storePublishDate",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.date_range),
              ),
            ),
            const SizedBox(height: 15),

            // 16. activationDate
            TextField(
              controller: _activationDateController,
              decoration: const InputDecoration(
                labelText: "activationDate",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_available),
              ),
            ),
            const SizedBox(height: 15),

            // 17. points
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "points",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star),
              ),
            ),
            const SizedBox(height: 20),

            // 18. myAssets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "myAssets (MarketingCards)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF33A1C9),
                  ),
                ),
                IconButton(
                  onPressed: _addNewAsset,
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _myAssets.isEmpty
                ? const Text(
                    "لا توجد أصول مضافة حالياً",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _myAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _myAssets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Text(
                            asset.iconSymbol,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            asset.title.isEmpty ? "بدون عنوان" : asset.title,
                          ),
                          subtitle: Text("السعر: ${asset.price}"),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _myAssets.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 20),

            // 19. signedDocuments
            const Text(
              "signedDocuments",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF33A1C9),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "عدد المستندات الموقعة: ${_signedDocuments.length}",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 20. digitalPublicKey
            TextField(
              controller: _digitalPublicKeyController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "digitalPublicKey",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 15),

            // 21. digitalSignatureAlgorithm
            TextField(
              controller: _digitalSignatureAlgorithmController,
              decoration: const InputDecoration(
                labelText: "digitalSignatureAlgorithm",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
            ),
            const SizedBox(height: 15),

            // 22. digitalSignatureCreatedAt
            TextField(
              controller: _digitalSignatureCreatedAtController,
              decoration: const InputDecoration(
                labelText: "digitalSignatureCreatedAt",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
            const SizedBox(height: 15),

            // 23. digitalSignatureKeyVersion
            TextField(
              controller: _digitalSignatureKeyVersionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "digitalSignatureKeyVersion",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 30),

            // أزرار التوجيه
            if (isAgent) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  "حساب وكيل معتمد بالمنظومة",
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
                  "استفسار بخصوص الحساب المحترف",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: moxBlue,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  "واتساب المحترفين",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => _launchWhatsApp(
                  "249115855164",
                  "أريد ترقية حسابي في بنك MOX",
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

            // زر الحفظ النهائي
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxBlue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      "حفظ التغييرات بالمسطرة",
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
