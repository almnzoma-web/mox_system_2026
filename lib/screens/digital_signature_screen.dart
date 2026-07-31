import 'dart:ui' as ui;
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart'; // تم تفعيل حزمة اختيار الملفات الحقيقية
import '../../models/user_model.dart';
import '../../services/storage_service.dart';

class DigitalSignatureScreen extends StatefulWidget {
  final UserModel currentUser;

  const DigitalSignatureScreen({super.key, required this.currentUser});

  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final Color moxGold = const Color(0xFFD4AF37);
  final TextEditingController _docTitleController = TextEditingController();

  final List<Offset?> _points = [];
  bool _isSigned = false;

  // متغيرات إدارة المستندات وتحديد مكان التوقيع التفاعلي
  String _loadedDocName = "مستند مستقل (بدون ملف خارجي)";
  String? _loadedDocPath;

  // إحداثيات موضع علامة التوقيع داخل المستند (نسبية داخل مساحة المعاينة)
  Offset _signatureMarkerPosition = const Offset(150, 150);

  // محتوى المستند المستقل الافتراضي
  final String _defaultDocSampleText = """
جمهورية السودان الرقمية - منظومة موكس (MOX)
إقرار وتعاقد سيادي معتمد

بموجب هذا المستند يتم اعتماد الشروط والسياسات الخاصة بالخدمات الرقمية المقدمة عبر المنظومة. 
هذا العقد ملزم لكافة الأطراف المتعاقدة ويخضع للوائح التوثيق الرقمي المعتمدة.

تنبيه هام: يتطلب اعتماد هذا العقد وضع التوقيع الرقمي في المكان المخصص أدناه وفقاً للمعايير السيادية المعتمدة.
""";

  @override
  void dispose() {
    _docTitleController.dispose();
    super.dispose();
  }

  // دالة تحميل المستند الحقيقي من الجهاز عبر file_picker لتشمل الويب والهاتف بكفاءة
  Future<void> _pickDocumentFromDevice() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg'],
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        setState(() {
          _loadedDocName = result.files.single.name;
          _loadedDocPath = result.files.single.path ?? result.files.single.name;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "📁 تم تحميل المستند '$_loadedDocName' بنجاح. اسحب مؤشر التوقيع بسلاسة لتحديد مكانه.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // إلغاء الاختيار من المستخدم
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ تم إلغاء عملية اختيار الملف."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ خطأ أثناء تحميل الملف من الجهاز: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // إعادة تعيين المستند إلى مستند مستقل
  void _resetToIndependentDocument() {
    setState(() {
      _loadedDocName = "مستند مستقل (بدون ملف خارجي)";
      _loadedDocPath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📄 تم التحويل إلى وضع المستند المستقل بنجاح."),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showClientDocumentsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "📂 مستندات عميل موكس الأرشيفية",
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFD4AF37)),
                const SizedBox(height: 10),
                Expanded(
                  child: widget.currentUser.myAssets.isEmpty
                      ? const Center(
                          child: Text(
                            "لا توجد مستندات موثقة حتى الآن",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.currentUser.myAssets.length,
                          itemBuilder: (context, index) {
                            final dynamic rawAsset =
                                widget.currentUser.myAssets[index];
                            final Map<String, dynamic> asset =
                                rawAsset is Map<String, dynamic>
                                ? rawAsset
                                : {
                                    'title': rawAsset.toString(),
                                    'date': '',
                                    'status': '',
                                  };

                            return Card(
                              color: Colors.black,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.verified,
                                  color: Color(0xFFD4AF37),
                                ),
                                title: Text(
                                  asset['title']?.toString() ??
                                      'مستند بدون عنوان',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "التاريخ: ${asset['date']?.toString().substring(0, 10) ?? ''} | الحالة: ${asset['status']?.toString() ?? ''}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.download_done,
                                  color: Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndDownloadDocument() async {
    if (_docTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ الرجاء كتابة عنوان أو وصف للمستند أولاً"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isSigned || _points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ لم يتم التوقيع! الرجاء التوقيع في المساحة المخصصة"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final Map<String, dynamic> signedAsset = {
        "title": _docTitleController.text.trim(),
        "moxId": widget.currentUser.moxId,
        "clientName": widget.currentUser.name,
        "date": DateTime.now().toIso8601String(),
        "type": "Digital Signature Seal & Download",
        "status": "ممتلك، موثق ومحمّل بصمة MOX",
        "docSource": _loadedDocName,
        "docPath": _loadedDocPath ?? "",
        "signatureCoordinates": {
          "dx": _signatureMarkerPosition.dx,
          "dy": _signatureMarkerPosition.dy,
        },
      };

      widget.currentUser.myAssets.add(signedAsset as dynamic);
      await StorageService.saveUsersList();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ تم اعتماد المستند وتنزيله بنجاح ببصمة MOX للعميل ${widget.currentUser.name}",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _points.clear();
        _isSigned = false;
        _docTitleController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ خطأ أثناء حفظ وتحميل التوقيع: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "مركز التوثيق والتوقيع السيادي (MOX)",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: moxGold, height: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // زر الأرشيف
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moxGold, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_special,
                        color: Color(0xFFD4AF37),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "مستندات عميل موكس",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "الأرشيف الرقمي (${widget.currentUser.myAssets.length} مستند)",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _showClientDocumentsModal,
                    child: const Text(
                      "فتح",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة بيانات العميل
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moxGold, width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: moxGold,
                    child: const Icon(Icons.verified_user, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "معرف MOX: ${widget.currentUser.moxId}",
                          style: TextStyle(color: moxGold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // خيارات تحميل المستند أو اعتماده كمستند مستقل
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[850],
                      foregroundColor: moxGold,
                      side: BorderSide(color: moxGold, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _pickDocumentFromDevice,
                    icon: const Icon(Icons.upload_file),
                    label: const Text(
                      "تحميل ملف خارجي",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.grey, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _resetToIndependentDocument,
                    icon: const Icon(Icons.note_alt, color: Color(0xFFD4AF37)),
                    label: const Text(
                      "مستند مستقل",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Text(
                "الحالة الحالية: $_loadedDocName",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: moxGold, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _docTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "عنوان أو وصف المستند المراد توقيعه وتحميله",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: moxGold, width: 2),
                ),
                prefixIcon: Icon(Icons.description, color: moxGold),
              ),
            ),
            const SizedBox(height: 20),

            // منطقة معاينة المستند مع حركة انسيابية تامة لعلامة التوقيع عبر GestureDetector المباشر
            const Text(
              "📄 معاينة المستند وموقع التوقيع التفاعلي (اسحب علامة البصمة بسلاسة لتحديد المكان):",
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double maxWidth = constraints.maxWidth - 40;
                  double maxHeight = constraints.maxHeight - 50;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: moxGold, width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _loadedDocName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: moxGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    "جاهز للإسقاط السيادي",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.grey),
                              Expanded(
                                child: Text(
                                  _defaultDocSampleText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: moxGold.withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      color: Color(0xFFD4AF37),
                                      size: 12,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "مستند مؤمن ببصمة وتوقيع رقمي من منظومة موكس",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // مؤشر التوقيع المتحرك بسلاسة مطلقة باستخدام GestureDetector المحسّن
                        Positioned(
                          left: _signatureMarkerPosition.dx.clamp(
                            10.0,
                            maxWidth > 0 ? maxWidth : 300.0,
                          ),
                          top: _signatureMarkerPosition.dy.clamp(
                            35.0,
                            maxHeight > 0 ? maxHeight : 200.0,
                          ),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _signatureMarkerPosition = Offset(
                                  (_signatureMarkerPosition.dx +
                                          details.delta.dx)
                                      .clamp(
                                        10.0,
                                        maxWidth > 0 ? maxWidth : 300.0,
                                      ),
                                  (_signatureMarkerPosition.dy +
                                          details.delta.dy)
                                      .clamp(
                                        35.0,
                                        maxHeight > 0 ? maxHeight : 200.0,
                                      ),
                                );
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: moxGold,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.pin_drop,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // لوحة الرسم الخاصة بالتوقيع الرقمي
            const Text(
              "✍️ مساحة التوقيع الرقمي (وقع يدويّاً داخل الإطار بالأسفل):",
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: moxGold, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                      _isSigned = true;
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: SignaturePainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _points.clear();
                    _isSigned = false;
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.orange, size: 18),
                label: const Text(
                  "إعادة التوقيع",
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // زر الاعتماد والحفظ النهائي
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: moxGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveAndDownloadDocument,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      "اعتماد، حفظ بالأصول وتحميل المستند ببصمة MOX",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
