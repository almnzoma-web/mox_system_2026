// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/user_model.dart';
import '../../models/signed_document.dart';
import '../../services/storage_service.dart';

class DigitalSignatureScreen extends StatefulWidget {
  final UserModel currentUser;

  const DigitalSignatureScreen({
    super.key,
    required this.currentUser,
    required UserModel user,
  });

  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final Color moxGold = const Color(0xFFD4AF37);

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _contentController = TextEditingController(
    text:
        'هذا المستند صادر إلكترونياً عبر منظومة MOX.\n\n'
        'أقر أنا الموقع أدناه بصحة البيانات الواردة في هذا المستند '
        'وأوافق على توثيقه رقمياً وفق نظام التوقيع الرقمي المعتمد.',
  );

  final List<Offset?> _points = [];

  // ignore: unused_field
  bool _isSigned = false;
  bool _processing = false;

  // ignore: unused_field
  Uint8List? _signatureImage;

  SignedDocument? _lastSignedDocument;
  Uint8List? _lastPdfBytes;

  final Ed25519 _algorithm = Ed25519();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ============================================================
  // تحويل التوقيع المرسوم إلى PNG
  // ============================================================

  Future<Uint8List?> _signatureToPng() async {
    if (_points.isEmpty) return null;

    try {
      const size = Size(600, 220);

      final recorder = ui.PictureRecorder();

      final canvas = Canvas(recorder);

      final background = Paint()..color = Colors.white;

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), background);

      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < _points.length - 1; i++) {
        final p1 = _points[i];
        final p2 = _points[i + 1];

        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }

      final picture = recorder.endRecording();

      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );

      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SHA256
  // ============================================================

  Future<String> _sha256(Uint8List data) async {
    final hash = await Sha256().hash(data);

    return base64UrlEncode(hash.bytes);
  }

  // ============================================================
  // إنشاء النص الأساسي للمستند
  // ============================================================

  String _buildDocumentText() {
    return '''
العنوان:
${_titleController.text.trim()}

الموقع:
${widget.currentUser.name}

معرف MOX:
${widget.currentUser.moxId}

رقم الهاتف:
${widget.currentUser.phone}

تاريخ التوقيع:
${DateTime.now().toIso8601String()}

--------------------------------------------------

${_contentController.text.trim()}

--------------------------------------------------

هذا المستند تم توقيعه رقمياً بواسطة منظومة MOX.
''';
  }

  // ============================================================
  // إنشاء PDF
  // ============================================================

  Future<Uint8List> _createPdf({
    required SignedDocument signed,
    required Uint8List signatureBytes,
  }) async {
    final pdf = pw.Document();

    final signatureImage = pw.MemoryImage(signatureBytes);

    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.amber, width: 2),
              ),
              child: pw.Center(
                child: pw.Text(
                  'MOX DIGITAL SIGNED DOCUMENT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),

            pw.SizedBox(height: 25),

            pw.Text(
              signed.title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              _contentController.text.trim(),
              style: const pw.TextStyle(fontSize: 13, lineSpacing: 5),
            ),

            pw.SizedBox(height: 30),

            pw.Divider(),

            pw.Text(
              'DIGITAL SIGNATURE INFORMATION',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 12),

            pw.Text('الاسم: ${signed.ownerName}'),

            pw.Text('MOX ID: ${signed.moxId}'),

            pw.Text('تاريخ التوقيع: ${signed.createdAt}'),

            pw.SizedBox(height: 20),

            pw.Center(
              child: pw.Container(
                width: 250,
                height: 100,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              'SHA-256:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.Text(
              signed.documentHash,
              style: const pw.TextStyle(fontSize: 8),
            ),

            pw.SizedBox(height: 12),

            pw.Text(
              'Digital Signature:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.Text(
              signed.digitalSignature,
              style: const pw.TextStyle(fontSize: 8),
            ),

            pw.SizedBox(height: 12),

            pw.Text(
              'Public Key:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.Text(signed.publicKey, style: const pw.TextStyle(fontSize: 8)),

            pw.SizedBox(height: 30),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: PdfColors.grey300,
              child: pw.Text(
                'تم إنشاء هذا المستند وتوقيعه تشفيرياً بواسطة MOX باستخدام Ed25519.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),

            pw.SizedBox(height: 15),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated: ${now.toIso8601String()}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // التوقيع الرقمي الحقيقي
  // ============================================================

  Future<void> _signDocument() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _message('اكتب عنوان المستند أولاً', Colors.orange);
      return;
    }

    if (_points.isEmpty) {
      _message('ارسم توقيعك أولاً', Colors.orange);
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      _message('محتوى المستند فارغ', Colors.orange);
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      // ----------------------------------------------------------
      // 1. صورة التوقيع
      // ----------------------------------------------------------

      final signatureBytes = await _signatureToPng();

      if (signatureBytes == null) {
        throw Exception('تعذر إنشاء صورة التوقيع');
      }

      // ----------------------------------------------------------
      // 2. إنشاء مفتاح Ed25519
      // ----------------------------------------------------------

      final keyPair = await _algorithm.newKeyPair();

      // ----------------------------------------------------------
      // 3. تجهيز المستند
      // ----------------------------------------------------------

      final documentText = _buildDocumentText();

      final documentBytes = Uint8List.fromList(utf8.encode(documentText));

      // ----------------------------------------------------------
      // 4. SHA256
      // ----------------------------------------------------------

      final hash = await _sha256(documentBytes);

      // ----------------------------------------------------------
      // 5. التوقيع التشفيري الحقيقي
      // ----------------------------------------------------------

      final signature = await _algorithm.sign(documentBytes, keyPair: keyPair);

      // ----------------------------------------------------------
      // 6. المفتاح العام
      // ----------------------------------------------------------

      final publicKey = await keyPair.extractPublicKey();

      final signatureBase64 = base64UrlEncode(signature.bytes);

      final publicKeyBase64 = base64UrlEncode(publicKey.bytes);

      final now = DateTime.now();

      final id = '${now.millisecondsSinceEpoch}-${widget.currentUser.moxId}';

      final signedDocument = SignedDocument(
        id: id,
        title: title,
        ownerName: widget.currentUser.name,
        moxId: widget.currentUser.moxId,
        createdAt: now.toIso8601String(),
        documentHash: hash,
        digitalSignature: signatureBase64,
        publicKey: publicKeyBase64,
        originalFileName: '$title.pdf',
      );

      // ----------------------------------------------------------
      // 7. إنشاء PDF يحمل التوقيع
      // ----------------------------------------------------------

      final pdfBytes = await _createPdf(
        signed: signedDocument,
        signatureBytes: signatureBytes,
      );

      // ----------------------------------------------------------
      // 8. حفظ البيانات في المستخدم
      // ----------------------------------------------------------

      widget.currentUser.signedDocuments = List<SignedDocument>.from(
        widget.currentUser.signedDocuments,
      )..add(signedDocument);

      // الاحتفاظ أيضاً بالبطاقة القديمة إن كانت مطلوبة
      // ويمكن حذف هذا الجزء لاحقاً إذا أردت فصل النظامين.

      await StorageService.updateUserPartial(widget.currentUser);

      await StorageService.saveUsersList();

      if (!mounted) return;

      setState(() {
        _signatureImage = signatureBytes;
        _lastSignedDocument = signedDocument;
        _lastPdfBytes = pdfBytes;
        _processing = false;
      });

      _message('تم إنشاء التوقيع الرقمي الحقيقي بنجاح', Colors.green);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processing = false;
      });

      _message('حدث خطأ أثناء التوقيع: $e', Colors.red);
    }
  }

  // ============================================================
  // معاينة PDF
  // ============================================================

  Future<void> _previewPdf() async {
    if (_lastPdfBytes == null) {
      _message('قم بتوقيع المستند أولاً', Colors.orange);
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) async {
        return _lastPdfBytes!;
      },
    );
  }

  // ============================================================
  // تحميل / مشاركة PDF
  // ============================================================

  Future<void> _downloadPdf() async {
    if (_lastPdfBytes == null) {
      _message('لا يوجد مستند موقع لتحميله', Colors.orange);
      return;
    }

    final title = _lastSignedDocument?.title ?? 'mox_signed_document';

    await Printing.sharePdf(bytes: _lastPdfBytes!, filename: '$title.pdf');
  }

  // ============================================================
  // تحقق من التوقيع
  // ============================================================

  Future<void> _verifyLastSignature() async {
    final signed = _lastSignedDocument;

    if (signed == null) {
      _message('لا يوجد توقيع للتحقق منه', Colors.orange);
      return;
    }

    try {
      final publicKeyBytes = base64Url.decode(signed.publicKey);

      final signatureBytes = base64Url.decode(signed.digitalSignature);

      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(signatureBytes, publicKey: publicKey);

      final originalText = _buildDocumentText();

      final originalBytes = Uint8List.fromList(utf8.encode(originalText));

      final valid = await _algorithm.verify(
        originalBytes,
        signature: signature,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                Icon(
                  valid ? Icons.verified : Icons.gpp_bad,
                  color: valid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  valid ? 'التوقيع صحيح' : 'التوقيع غير صحيح',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              valid
                  ? 'تم التحقق من التوقيع التشفيري Ed25519.\n\n'
                        'المستند مطابق للبيانات التي تم توقيعها.'
                  : 'فشل التحقق من التوقيع.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق', style: TextStyle(color: moxGold)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _message('تعذر التحقق من التوقيع: $e', Colors.red);
    }
  }

  // ============================================================
  // رسالة
  // ============================================================

  void _message(String text, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final signed = _lastSignedDocument;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,

        title: const Text(
          'التوقيع الرقمي الحقيقي - MOX',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),

          child: Container(height: 2, color: Color(0xFFD4AF37)),
        ),
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // المستخدم
                // ==================================================
                Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: moxGold),
                  ),

                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: moxGold,

                        child: const Icon(
                          Icons.verified_user,
                          color: Colors.black,
                        ),
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
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              'MOX ID: ${widget.currentUser.moxId}',
                              style: TextStyle(color: moxGold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // عنوان
                // ==================================================
                TextField(
                  controller: _titleController,

                  style: const TextStyle(color: Colors.white),

                  decoration: InputDecoration(
                    labelText: 'عنوان المستند',

                    labelStyle: const TextStyle(color: Colors.grey),

                    prefixIcon: Icon(Icons.description, color: moxGold),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),

                      borderSide: const BorderSide(color: Colors.grey),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: moxGold, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // محتوى المستند
                // ==================================================
                TextField(
                  controller: _contentController,

                  minLines: 8,
                  maxLines: 15,

                  style: const TextStyle(color: Colors.white, height: 1.5),

                  decoration: InputDecoration(
                    labelText: 'محتوى المستند',

                    labelStyle: const TextStyle(color: Colors.grey),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),

                      borderSide: const BorderSide(color: Colors.grey),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: moxGold, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // مساحة التوقيع
                // ==================================================
                const Text(
                  '✍️ ارسم توقيعك داخل الإطار',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 220,

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: moxGold, width: 2),
                  ),

                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _points.add(details.localPosition);

                        _isSigned = true;
                      });
                    },

                    onPanEnd: (_) {
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

                const SizedBox(height: 8),

                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _points.clear();
                      _isSigned = false;
                      _signatureImage = null;
                      _lastPdfBytes = null;
                      _lastSignedDocument = null;
                    });
                  },

                  icon: const Icon(Icons.refresh, color: Colors.orange),

                  label: const Text(
                    'مسح التوقيع',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // زر التوقيع
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _signDocument,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: moxGold,

                      foregroundColor: Colors.black,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    icon: const Icon(Icons.draw),

                    label: const Text(
                      'توقيع المستند رقمياً وإنشاء PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // بعد التوقيع
                // ==================================================
                if (signed != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(color: Colors.green),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green),

                            SizedBox(width: 8),

                            Text(
                              'تم التوقيع الرقمي بنجاح',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        Text(
                          'SHA-256:',
                          style: TextStyle(
                            color: moxGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        SelectableText(
                          signed.documentHash,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'التوقيع الرقمي:',
                          style: TextStyle(
                            color: moxGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        SelectableText(
                          signed.digitalSignature,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // المعاينة والتحميل والتحقق
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _previewPdf,

                          icon: const Icon(Icons.visibility),

                          label: const Text('معاينة PDF'),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadPdf,

                          icon: const Icon(Icons.download),

                          label: const Text('تحميل PDF'),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,

                    child: OutlinedButton.icon(
                      onPressed: _verifyLastSignature,

                      icon: const Icon(Icons.security, color: Colors.amber),

                      label: const Text(
                        'التحقق من صحة التوقيع الرقمي',
                        style: TextStyle(color: Colors.amber),
                      ),

                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),

          // ========================================================
          // Processing
          // ========================================================
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.88),

              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(25),

                  margin: const EdgeInsets.all(30),

                  decoration: BoxDecoration(
                    color: Colors.grey[900],

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(color: moxGold, width: 2),
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      CircularProgressIndicator(color: moxGold),

                      const SizedBox(height: 20),

                      const Text(
                        'جاري إنشاء التوقيع الرقمي...',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'إنشاء SHA-256\n'
                        'إنشاء مفتاح Ed25519\n'
                        'توقيع المستند\n'
                        'إنشاء ملف PDF',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// Signature Painter
// ================================================================

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return true;
  }
}
