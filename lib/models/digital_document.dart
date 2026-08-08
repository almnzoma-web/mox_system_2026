import 'dart:convert';

/// ============================================================
/// MOX DIGITAL DOCUMENT
/// نموذج المستند الرقمي المعتمد في منظومة MOX
/// ============================================================

class DigitalDocument {
  // ============================================================
  // الهوية
  // ============================================================

  final String id;

  String title;
  String description;

  // ============================================================
  // مالك المستند
  // ============================================================

  String ownerMoxId;
  String ownerPhone;
  String ownerName;

  // ============================================================
  // الملف الأصلي
  // ============================================================

  String fileName;
  String fileExtension;

  /// نوع الملف:
  /// pdf / png / jpg / jpeg / doc / docx / txt / independent
  String fileType;

  /// محتوى الملف Base64 عند الحاجة للتخزين المحلي/السحابي.
  String? fileBase64;

  /// حجم الملف بالبايت.
  int fileSize;

  // ============================================================
  // التوقيع الرقمي
  // ============================================================

  bool isSigned;

  /// التوقيع المرسوم نفسه بصيغة Base64 PNG.
  String? signatureBase64;

  /// بصمة المستند.
  String documentHash;

  /// بصمة التوقيع.
  String signatureHash;

  /// نسخة البصمة النهائية للمستند الموقع.
  String digitalFingerprint;

  // ============================================================
  // بيانات التوقيع
  // ============================================================

  String signedAt;

  String signedBy;

  /// إحداثيات موضع التوقيع داخل واجهة المعاينة.
  double signatureX;
  double signatureY;

  // ============================================================
  // حالة المستند
  // ============================================================

  /// draft
  /// signed
  /// verified
  /// revoked
  String status;

  bool isVerified;

  // ============================================================
  // بيانات إضافية
  // ============================================================

  String createdAt;
  String updatedAt;

  String issuer;

  String version;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  DigitalDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerMoxId,
    required this.ownerPhone,
    required this.ownerName,
    this.fileName = '',
    this.fileExtension = '',
    this.fileType = 'independent',
    this.fileBase64,
    this.fileSize = 0,
    this.isSigned = false,
    this.signatureBase64,
    this.documentHash = '',
    this.signatureHash = '',
    this.digitalFingerprint = '',
    this.signedAt = '',
    this.signedBy = '',
    this.signatureX = 0,
    this.signatureY = 0,
    this.status = 'draft',
    this.isVerified = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.issuer = 'MOX Digital',
    this.version = '1.0',
  });

  // ============================================================
  // FACTORY ID
  // ============================================================

  static String generateId() {
    final now = DateTime.now();

    return 'MOX-DOC-'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.microsecondsSinceEpoch}';
  }

  // ============================================================
  // FACTORY CREATE
  // ============================================================

  factory DigitalDocument.create({
    required String title,
    required String description,
    required String ownerMoxId,
    required String ownerPhone,
    required String ownerName,
    String fileName = '',
    String fileExtension = '',
    String fileType = 'independent',
    String? fileBase64,
    int fileSize = 0,
  }) {
    final now = DateTime.now().toIso8601String();

    return DigitalDocument(
      id: generateId(),
      title: title,
      description: description,
      ownerMoxId: ownerMoxId,
      ownerPhone: ownerPhone,
      ownerName: ownerName,
      fileName: fileName,
      fileExtension: fileExtension,
      fileType: fileType,
      fileBase64: fileBase64,
      fileSize: fileSize,
      createdAt: now,
      updatedAt: now,
      issuer: 'MOX Digital',
      version: '1.0',
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool get hasFile {
    return fileBase64 != null && fileBase64!.trim().isNotEmpty;
  }

  bool get hasSignature {
    return signatureBase64 != null && signatureBase64!.trim().isNotEmpty;
  }

  bool get isIndependentDocument {
    return fileType == 'independent';
  }

  bool get isPdf {
    return fileExtension.toLowerCase() == 'pdf';
  }

  bool get isImage {
    final ext = fileExtension.toLowerCase();

    return ext == 'png' || ext == 'jpg' || ext == 'jpeg';
  }

  bool get isText {
    return fileExtension.toLowerCase() == 'txt';
  }

  bool get isFinalized {
    return status == 'signed' || status == 'verified';
  }

  // ============================================================
  // SIGN
  // ============================================================

  void markAsSigned({
    required String signatureBase64,
    required String documentHash,
    required String signatureHash,
    required String digitalFingerprint,
    required String signedBy,
    double signatureX = 0,
    double signatureY = 0,
  }) {
    this.signatureBase64 = signatureBase64;

    this.documentHash = documentHash;

    this.signatureHash = signatureHash;

    this.digitalFingerprint = digitalFingerprint;

    this.signedBy = signedBy;

    this.signatureX = signatureX;

    this.signatureY = signatureY;

    isSigned = true;

    isVerified = true;

    status = 'verified';

    final now = DateTime.now().toIso8601String();

    signedAt = now;
    updatedAt = now;
  }

  // ============================================================
  // REVOKE
  // ============================================================

  void revoke() {
    status = 'revoked';
    isVerified = false;
    updatedAt = DateTime.now().toIso8601String();
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'title': title,
      'description': description,

      'ownerMoxId': ownerMoxId,
      'ownerPhone': ownerPhone,
      'ownerName': ownerName,

      'fileName': fileName,
      'fileExtension': fileExtension,
      'fileType': fileType,
      'fileBase64': fileBase64,
      'fileSize': fileSize,

      'isSigned': isSigned,

      'signatureBase64': signatureBase64,

      'documentHash': documentHash,
      'signatureHash': signatureHash,
      'digitalFingerprint': digitalFingerprint,

      'signedAt': signedAt,
      'signedBy': signedBy,

      'signatureX': signatureX,
      'signatureY': signatureY,

      'status': status,
      'isVerified': isVerified,

      'createdAt': createdAt,
      'updatedAt': updatedAt,

      'issuer': issuer,
      'version': version,
    };
  }

  // ============================================================
  // FROM JSON
  // ============================================================

  factory DigitalDocument.fromJson(Map<String, dynamic> json) {
    return DigitalDocument(
      id: json['id']?.toString() ?? generateId(),

      title: json['title']?.toString() ?? '',

      description: json['description']?.toString() ?? '',

      ownerMoxId: json['ownerMoxId']?.toString() ?? '',

      ownerPhone: json['ownerPhone']?.toString() ?? '',

      ownerName: json['ownerName']?.toString() ?? '',

      fileName: json['fileName']?.toString() ?? '',

      fileExtension: json['fileExtension']?.toString() ?? '',

      fileType: json['fileType']?.toString() ?? 'independent',

      fileBase64: json['fileBase64']?.toString(),

      fileSize: _parseInt(json['fileSize']),

      isSigned: _parseBool(json['isSigned']),

      signatureBase64: json['signatureBase64']?.toString(),

      documentHash: json['documentHash']?.toString() ?? '',

      signatureHash: json['signatureHash']?.toString() ?? '',

      digitalFingerprint: json['digitalFingerprint']?.toString() ?? '',

      signedAt: json['signedAt']?.toString() ?? '',

      signedBy: json['signedBy']?.toString() ?? '',

      signatureX: _parseDouble(json['signatureX']),

      signatureY: _parseDouble(json['signatureY']),

      status: json['status']?.toString() ?? 'draft',

      isVerified: _parseBool(json['isVerified']),

      createdAt: json['createdAt']?.toString() ?? '',

      updatedAt: json['updatedAt']?.toString() ?? '',

      issuer: json['issuer']?.toString() ?? 'MOX Digital',

      version: json['version']?.toString() ?? '1.0',
    );
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory DigitalDocument.fromMap(Map<String, dynamic> map) {
    return DigitalDocument.fromJson(map);
  }

  // ============================================================
  // JSON STRING
  // ============================================================

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory DigitalDocument.fromJsonString(String value) {
    return DigitalDocument.fromJson(
      Map<String, dynamic>.from(jsonDecode(value)),
    );
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  DigitalDocument copyWith({
    String? title,
    String? description,
    String? ownerMoxId,
    String? ownerPhone,
    String? ownerName,
    String? fileName,
    String? fileExtension,
    String? fileType,
    String? fileBase64,
    int? fileSize,
    bool? isSigned,
    String? signatureBase64,
    String? documentHash,
    String? signatureHash,
    String? digitalFingerprint,
    String? signedAt,
    String? signedBy,
    double? signatureX,
    double? signatureY,
    String? status,
    bool? isVerified,
    String? createdAt,
    String? updatedAt,
    String? issuer,
    String? version,
  }) {
    return DigitalDocument(
      id: id,

      title: title ?? this.title,
      description: description ?? this.description,

      ownerMoxId: ownerMoxId ?? this.ownerMoxId,

      ownerPhone: ownerPhone ?? this.ownerPhone,

      ownerName: ownerName ?? this.ownerName,

      fileName: fileName ?? this.fileName,

      fileExtension: fileExtension ?? this.fileExtension,

      fileType: fileType ?? this.fileType,

      fileBase64: fileBase64 ?? this.fileBase64,

      fileSize: fileSize ?? this.fileSize,

      isSigned: isSigned ?? this.isSigned,

      signatureBase64: signatureBase64 ?? this.signatureBase64,

      documentHash: documentHash ?? this.documentHash,

      signatureHash: signatureHash ?? this.signatureHash,

      digitalFingerprint: digitalFingerprint ?? this.digitalFingerprint,

      signedAt: signedAt ?? this.signedAt,

      signedBy: signedBy ?? this.signedBy,

      signatureX: signatureX ?? this.signatureX,

      signatureY: signatureY ?? this.signatureY,

      status: status ?? this.status,

      isVerified: isVerified ?? this.isVerified,

      createdAt: createdAt ?? this.createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

      issuer: issuer ?? this.issuer,

      version: version ?? this.version,
    );
  }

  // ============================================================
  // OPERATORS
  // ============================================================

  dynamic operator [](String key) {
    return toJson()[key];
  }

  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'title':
        title = value?.toString() ?? '';
        break;

      case 'description':
        description = value?.toString() ?? '';
        break;

      case 'ownerMoxId':
        ownerMoxId = value?.toString() ?? '';
        break;

      case 'ownerPhone':
        ownerPhone = value?.toString() ?? '';
        break;

      case 'ownerName':
        ownerName = value?.toString() ?? '';
        break;

      case 'fileName':
        fileName = value?.toString() ?? '';
        break;

      case 'fileExtension':
        fileExtension = value?.toString() ?? '';
        break;

      case 'fileType':
        fileType = value?.toString() ?? 'independent';
        break;

      case 'fileBase64':
        fileBase64 = value?.toString();
        break;

      case 'fileSize':
        fileSize = _parseInt(value);
        break;

      case 'isSigned':
        isSigned = _parseBool(value);
        break;

      case 'signatureBase64':
        signatureBase64 = value?.toString();
        break;

      case 'documentHash':
        documentHash = value?.toString() ?? '';
        break;

      case 'signatureHash':
        signatureHash = value?.toString() ?? '';
        break;

      case 'digitalFingerprint':
        digitalFingerprint = value?.toString() ?? '';
        break;

      case 'signedAt':
        signedAt = value?.toString() ?? '';
        break;

      case 'signedBy':
        signedBy = value?.toString() ?? '';
        break;

      case 'signatureX':
        signatureX = _parseDouble(value);
        break;

      case 'signatureY':
        signatureY = _parseDouble(value);
        break;

      case 'status':
        status = value?.toString() ?? 'draft';
        break;

      case 'isVerified':
        isVerified = _parseBool(value);
        break;

      case 'createdAt':
        createdAt = value?.toString() ?? '';
        break;

      case 'updatedAt':
        updatedAt = value?.toString() ?? '';
        break;

      case 'issuer':
        issuer = value?.toString() ?? 'MOX Digital';
        break;

      case 'version':
        version = value?.toString() ?? '1.0';
        break;
    }
  }

  // ============================================================
  // PARSERS
  // ============================================================

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
