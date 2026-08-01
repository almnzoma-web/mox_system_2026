import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'external_store_front_screen.dart';

class ClientStoreAdminScreen extends StatefulWidget {
  final UserModel user;

  const ClientStoreAdminScreen({
    super.key,
    required this.user,
    required List<Map<String, dynamic>> clientCards,
  });

  @override
  State<ClientStoreAdminScreen> createState() => _ClientStoreAdminScreenState();
}

class _ClientStoreAdminScreenState extends State<ClientStoreAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();

  List<Map<String, dynamic>> _myCards = [];

  @override
  void initState() {
    super.initState();
    _whatsappController.text = widget.user.phone;
    _loadExistingCards();
  }

  Future<void> _loadExistingCards() async {
    try {
      final cards = await StorageService.getClientCards(widget.user.moxId);
      if (mounted) {
        setState(() {
          _myCards = cards;
        });
      }
    } catch (_) {}
  }

  Future<void> _publishStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newCard = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'whatsapp': _whatsappController.text.trim(),
        'facebook': _facebookController.text.trim(),
      };

      // تحديث القائمة المحلية فوراً
      final updatedCards = List<Map<String, dynamic>>.from(_myCards);
      updatedCards.add(newCard);

      // حفظ البطاقات عبر خدمة التخزين السيادية
      await StorageService.saveClientCards(widget.user.moxId, updatedCards);

      if (mounted) {
        setState(() {
          _myCards = updatedCards;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم نشر الدكان والمتجر وتوليد رابط العميل بنجاح"),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _descriptionController.clear();
        _priceController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء النشر: $e"),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF28A9CC),
        title: Text(
          "إدارة دكان العميل: ${widget.user.name}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                "أضف بطاقة أو عرض جديد لمتجرك الرقمي",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان البطاقة أو الخدمة',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف المنتج أو الخدمة',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'يرجى إدخال الوصف' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (ج.س)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'يرجى إدخال السعر' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'رقم الواتساب للطلب',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facebookController,
                decoration: const InputDecoration(
                  labelText: 'رابط تفاصيل إضافية (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A9CC),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _publishStore,
                icon: const Icon(Icons.verified_rounded, color: Colors.white),
                label: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "نشر الدكان والمتجر وتوليد رابط العميل (365 يوم)",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExternalStoreFrontScreen(
                        user: widget.user,
                        clientCards: _myCards,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "معاينة واجهة المتجر الخارجية",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
