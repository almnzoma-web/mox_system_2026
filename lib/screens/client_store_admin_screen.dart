import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../services/storage_service.dart';
import 'digital_signature_screen.dart';

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

  // قوائم للتحكم بالبطاقات وتنشيطها وتصنيفاتها
  late List<bool> _cardActivationFlags;
  late List<String> _cardCategoryTypes;
  late List<MarketingCard> _availableCardsPoolObjects;

  bool _isPublishing = false;

  // حالة زر التنشيط الأساسي السفلي: "طلب تنشيط"، "قيد المراجعة"، "نشط"
  String _activationButtonState = "طلب تنشيط";

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone;

    if (widget.user.name.isNotEmpty) {
      _storeNameController.text = widget.user.name;
    }
    if (widget.user.address.isNotEmpty) {
      _businessCategoryController.text = widget.user.address;
    }
    if (widget.user.storeDescription.isNotEmpty) {
      _descriptionController.text = widget.user.storeDescription;
    }

    // جلب البطاقات المتاحة ككائنات
    _availableCardsPoolObjects = widget.clientCards
        .map((cardMap) => MarketingCard.fromJson(cardMap))
        .toList();

    // تهيئة حالة مربعات التنشيط لكل بطاقة بناءً على أصول المستخدم المحفوظة
    _cardActivationFlags = List.generate(_availableCardsPoolObjects.length, (
      index,
    ) {
      String cardTitle = _availableCardsPoolObjects[index].title;
      var existingAsset = widget.user.myAssets.firstWhere(
        (asset) => asset.title == cardTitle,
        orElse: () => MarketingCard(
          title: '',
          description: '',
          whatsapp: '',
          facebookUrl: '',
          isApproved: false,
        ),
      );
      return existingAsset.isApproved && existingAsset.title.isNotEmpty;
    });

    // تهيئة التصنيفات الافتراضية لكل بطاقة (بطاقة)
    _cardCategoryTypes = List.generate(_availableCardsPoolObjects.length, (
      index,
    ) {
      return "بطاقة";
    });

    // فحص حالة التنشيط وصلاحية الـ 365 يوم
    _checkStoreActivationStatus();
  }

  void _checkStoreActivationStatus() {
    if (widget.user.storePublishDate == null ||
        widget.user.storePublishDate!.trim().isEmpty ||
        widget.user.storePublishDate == "null") {
      _activationButtonState = "طلب تنشيط";
    } else {
      try {
        DateTime publishDate = DateTime.parse(widget.user.storePublishDate!);
        DateTime expiryDate = publishDate.add(const Duration(days: 365));
        if (DateTime.now().isAfter(expiryDate)) {
          _activationButtonState =
              "طلب تنشيط"; // انتهت الـ 365 يوم وتحتاج تجديد
        } else {
          _activationButtonState = "نشط"; // سارية ضمن الـ 365 يوم
        }
      } catch (_) {
        _activationButtonState = "طلب تنشيط";
      }
    }
  }

  // منطق زر التنشيط الأساسي في أسفل الصفحة
  void _handleActivationButtonPress() {
    if (_activationButtonState == "طلب تنشيط") {
      setState(() {
        _activationButtonState = "قيد المراجعة";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⏳ تم إرسال طلب التنشيط للمدير.. بانتظار الاعتماد السيادي.",
          ),
          backgroundColor: Colors.orange,
        ),
      );

      // محاكاة موافقة المدير بعد ثوانٍ لتفعيل المتجر والبطاقات لمدة 365 يوم
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _activationButtonState = "نشط";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "✅ تمت موافقة المدير! تم تنشيط المتجر لمدة 365 يوم بنجاح.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  Future<void> _publishStore() async {
    // شرط: يجب أن يكون زر التنشيط الأساسي في وضع "نشط"
    if (_activationButtonState != "نشط") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ تنبيه: يجب اعتماد طلب التنشيط (أن يصبح نشطاً) أولاً لحفظ ونشر البطاقات!",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isPublishing = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      // جمع البطاقات التي تم تفعيل مربع التنشيط الخاص بها فقط
      List<MarketingCard> updatedAssets = [];
      for (int i = 0; i < _availableCardsPoolObjects.length; i++) {
        if (_cardActivationFlags[i]) {
          var card = _availableCardsPoolObjects[i];
          updatedAssets.add(
            card.copyWith(
              whatsapp: _phoneController.text.trim(),
              isApproved: true,
            ),
          );
        }
      }

      if (updatedAssets.isEmpty) {
        setState(() {
          _isPublishing = false;
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ تنبيه: لم تقم بتنشيط أي بطاقة (بوضع علامة صح) لنشرها!",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      String finalPublishTimestamp = DateTime.now().toIso8601String();

      UserModel updatedUser = widget.user.copyWith(
        name: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _businessCategoryController.text.trim(),
        storeDescription: _descriptionController.text.trim(),
        myAssets: updatedAssets,
        storePublishDate: finalPublishTimestamp,
        activationDate: finalPublishTimestamp,
      );

      await StorageService.addUser(updatedUser);
      await StorageService.saveUser(updatedUser);
      await StorageService.updateUserPartial(updatedUser);

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🚀 تم تحديث ونشر الدكان وبطاقاته المعتمدة في رابط العميل بنجاح",
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, updatedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF28A9CC),
            title: const Text(
              "لوحة إعدادات المتجر السيادي",
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
                    "🛒 إعدادات المتجر السيادي وإدارة البطاقات الكاملة",
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
                    validator: (val) => val == null || val.isEmpty
                        ? "يرجى إدخال اسم الدكان"
                        : null,
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
                      labelText: "٥- وصف المتجر العام في حدود ٢٥٦ حرف (إلزامي)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty
                        ? "يرجى كتابة وصف موجز للمتجر"
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "٦ & ٧- استعراض البطاقات الكاملة مع خيارات (بطاقة، قسم، رف) وتنشيطها:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // عرض جميع البطاقات المتاحة بالكامل مع القائمة المنسدلة ومربع التنشيط لكل بطاقة
                  ...List.generate(_availableCardsPoolObjects.length, (index) {
                    var card = _availableCardsPoolObjects[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // رأس البطاقة: القائمة المنسدلة الصغيرة (بطاقة، قسم، رف) + مربع التنشيط
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _cardCategoryTypes[index],
                                    underline: const SizedBox(),
                                    isDense: true,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1B6B80),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: ["بطاقة", "قسم", "رف"].map((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _cardCategoryTypes[index] = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      "تنشيط",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    Checkbox(
                                      value: _cardActivationFlags[index],
                                      activeColor: const Color(0xFF28A9CC),
                                      // مشروط: لا يعمل الا إذا كان زر التنشيط الأساسي في وضع "نشط"
                                      onChanged:
                                          (_activationButtonState == "نشط")
                                          ? (bool? value) {
                                              setState(() {
                                                _cardActivationFlags[index] =
                                                    value ?? false;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              card.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1B6B80),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "السعر: ${card.price}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                label: Text(
                                  "التصنيف المحدد: ${_cardCategoryTypes[index]}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: const Color(0xFF1B6B80),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // زر التنشيط الأساسي في أسفل الصفحة (وفق قاعدة 365 يوم)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF28A9CC)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "منظومة التنشيط السيادي (كل 365 يوم)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1B6B80),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activationButtonState == "نشط"
                                ? Colors.green
                                : _activationButtonState == "قيد المراجعة"
                                ? Colors.orange
                                : const Color(0xFF28A9CC),
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _activationButtonState == "طلب تنشيط"
                              ? _handleActivationButtonPress
                              : null,
                          child: Text(
                            _activationButtonState,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // زر التوقيع الرقمي السيادي بنفس تصميمه الأصلي
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DigitalSignatureScreen(
                              currentUser: widget.user,
                            ),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.gesture_rounded,
                              color: Color(0xFF1B6B80),
                              size: 28,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "بوابة التوقيع الرقمي السيادي",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1B6B80),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "اعتمد عقودك ومستنداتك بتوقيع رقمي موثق بالمسطرة",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Color(0xFF1B6B80),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // زر النشر والحفظ في الذاكرة الدائمة
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A9CC),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isPublishing ? null : _publishStore,
                    icon: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "نشر وتحديث الدكان والبطاقات المفعلة",
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
        ),

        if (_isPublishing)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFF28A9CC)),
                    SizedBox(height: 18),
                    Text(
                      "جاري حفظ ونشر البطاقات المفعلة في رابط العميل...",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B6B80),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
