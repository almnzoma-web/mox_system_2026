import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/marketing_card.dart';
import '../data/user_data.dart';
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

  late List<String?> _selectedCards;
  late List<String> _availableCardsPool;

  bool _isAuthorized = false;
  bool _isPublishing = false;
  bool _isStoreExpired =
      false; // فحص ما إذا كان المتجر منتهي الصلاحية (بعد 365 يوم)

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

    _availableCardsPool = widget.clientCards
        .map((card) => card['title'].toString())
        .toList();

    List<String> activeCardTitles = widget.user.myAssets
        .where((asset) => asset.isApproved && asset.title.isNotEmpty)
        .map((asset) => asset.title)
        .toList();

    _selectedCards = List.generate(
      5,
      (index) =>
          index < activeCardTitles.length ? activeCardTitles[index] : null,
    );

    // 🛡️ فحص صلاحية الـ 365 يوم للمتجر:
    // إذا كان المتجر جديداً كلياً (ليس لديه تاريخ تفعيل أو إطلاق سابق)، يُعتبر مصرحاً له مباشرة دون حوار معوق.
    // أما إذا كان لديه تاريخ تفعيل قديم وتمضي عليه أكثر من سنة (منتهي)، فيتطلب التحقق والتنشيط.
    if (widget.user.storePublishDate == null ||
        widget.user.storePublishDate!.trim().isEmpty ||
        widget.user.storePublishDate == "null") {
      _isAuthorized = true; // متجر لأول مرة يفتح مباشرة
      _isStoreExpired = false;
    } else {
      try {
        DateTime publishDate = DateTime.parse(widget.user.storePublishDate!);
        DateTime expiryDate = publishDate.add(const Duration(days: 365));
        if (DateTime.now().isAfter(expiryDate)) {
          _isStoreExpired = true; // انتهت الـ 365 يوم ويحتاج تنشيط
          _isAuthorized = false;
        } else {
          _isAuthorized = true; // ساري المفعول
          _isStoreExpired = false;
        }
      } catch (_) {
        _isAuthorized = true;
      }
    }

    // استدعاء حوار التحقق فقط إذا كان المتجر منتهياً
    if (_isStoreExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSecurityLoginDialog();
      });
    }
  }

  void _showSecurityLoginDialog() async {
    await StorageService.ensureLoaded();

    final TextEditingController moxInputController = TextEditingController();
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
              "تنشيط المتجر (انتهت فترة 365 يوم)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B6B80),
                fontSize: 13,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "انتهت صلاحية متجرك (365 يوم). أرجو إدخال رقم موكس وكلمة السر للتنشيط والتجديد:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: moxInputController,
              decoration: const InputDecoration(
                labelText: "رقم موكس (MOX)",
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
              String enteredMox = moxInputController.text.trim();
              String enteredPassword = passwordInputController.text.trim();

              bool isMoxMatchedInProfile = false;
              bool isPasswordMatched = false;

              try {
                bool matchesUserMox =
                    (widget.user.moxId.trim().toUpperCase() ==
                        enteredMox.toUpperCase()) ||
                    (widget.user.guardianMoxId != null &&
                        widget.user.guardianMoxId!.trim().toUpperCase() ==
                            enteredMox.toUpperCase());

                if (enteredMox.isNotEmpty && matchesUserMox) {
                  isMoxMatchedInProfile = true;
                } else {
                  for (var u in registeredUsers) {
                    bool matchesStorageMox =
                        (u.moxId.trim().toUpperCase() ==
                            enteredMox.toUpperCase()) ||
                        (u.guardianMoxId != null &&
                            u.guardianMoxId!.trim().toUpperCase() ==
                                enteredMox.toUpperCase());
                    if (matchesStorageMox && enteredMox.isNotEmpty) {
                      isMoxMatchedInProfile = true;
                      break;
                    }
                  }
                }

                if (isMoxMatchedInProfile) {
                  if (widget.user.password == enteredPassword &&
                      enteredPassword.isNotEmpty) {
                    isPasswordMatched = true;
                  } else {
                    for (var u in registeredUsers) {
                      bool matchesStorageMox =
                          (u.moxId.trim().toUpperCase() ==
                              enteredMox.toUpperCase()) ||
                          (u.guardianMoxId != null &&
                              u.guardianMoxId!.trim().toUpperCase() ==
                                  enteredMox.toUpperCase());
                      if (matchesStorageMox &&
                          u.password == enteredPassword &&
                          enteredPassword.isNotEmpty) {
                        isPasswordMatched = true;
                        break;
                      }
                    }
                  }
                }
              } catch (_) {
                isMoxMatchedInProfile = false;
                isPasswordMatched = false;
              }

              if (!mounted) return;
              Navigator.pop(ctx);

              if (!isMoxMatchedInProfile || !isPasswordMatched) {
                setState(() {
                  _isAuthorized = false;
                });
                _showLuxuryErrorDialog();
              } else {
                setState(() {
                  _isAuthorized = true;
                  _isStoreExpired = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ تم التنشيط بنجاح لمدة 365 يوم جديدة - مرحباً بك",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              "تحقـق وتنشـيط",
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
              "خطأ في بيانات التنشيط",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: const Text(
          "عفواً.. رقم موكس المدخل غير مطابق أو كلمة السر غير صحيحة لتنشيط المتجر 🤚",
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

  Future<void> _publishStore() async {
    if (!_isAuthorized && _isStoreExpired) {
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
              "⚠️ تنبيه: يجب اختيار بطاقة منشطة واحدة على الأقل لنشر المتجر!",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        _isPublishing = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      List<MarketingCard> updatedAssets = [];
      for (var cardTitle in _selectedCards) {
        if (cardTitle != null && cardTitle.trim().isNotEmpty) {
          try {
            var originalCardData = widget.clientCards.firstWhere(
              (c) => c['title'].toString() == cardTitle,
            );
            var cardModel = MarketingCard.fromJson(originalCardData);
            updatedAssets.add(
              cardModel.copyWith(
                whatsapp: _phoneController.text.trim(),
                isApproved: true,
              ),
            );
          } catch (_) {}
        }
      }

      // إذا كان المتجر ينشأ لأول مرة أو تجدد، نحدث تاريخ النشر والتنشيط
      String finalPublishTimestamp =
          (widget.user.storePublishDate != null &&
              widget.user.storePublishDate!.trim().isNotEmpty &&
              widget.user.storePublishDate != "null" &&
              !_isStoreExpired)
          ? widget.user.storePublishDate!
          : DateTime.now().toIso8601String();

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
          content: Text("🚀 تم تحديث ونشر المتجر بنجاح لمدة 365 يوم"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, updatedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان المتجر منتهي الصلاحية ولم يتم ترخيصه بعد، اعرض شاشة الانتظار أو التنبيه بدلاً من الشاشة البيضاء
    if (!_isAuthorized && _isStoreExpired) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.redAccent,
          title: const Text(
            "متجر منتهي الصلاحية (يتطلب تنشيط 365 يوم)",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  "انتهت صلاحية الـ 365 يوم لهذا المتجر.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A9CC),
                  ),
                  onPressed: _showSecurityLoginDialog,
                  icon: const Icon(Icons.verified, color: Colors.white),
                  label: const Text(
                    "إدخال بيانات التنشيط الآن",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF28A9CC),
            title: const Text(
              "لوحة إعدادات المتجر",
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
                    "🛒 إعدادات المتجر السيادي وإدارة الـ 5 رفوف (النسخة المعتمدة)",
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
                  const SizedBox(height: 15),
                  const Text(
                    "٦ & ٧- ربط البطاقات المنشطة (لا يتم نشر سوى البطاقات المحفوظة والمعتمدة فقط)",
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
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
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
                  const SizedBox(height: 20),

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
                      "نشر وتحديث الدكان والمتجر (365 يوم من أول إطلاق)",
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
                      "جاري حفظ وتثبيت النسخة المعتمدة لمتجرك...",
                      style: TextStyle(
                        fontSize: 16,
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
