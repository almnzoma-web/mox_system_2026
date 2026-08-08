import 'dart:convert';

/// ============================================================
/// MOX Digital Document
/// نموذج المستند الرقمي المعتمد
///
/// هذا النموذج مستقل عن MarketingCard.
/// وهو الأساس الذي سنبني عليه:
/// - التوقيع الرقمي
/// - بصمة المستند
/// - التحقق من التوقيع
/// - الأرشيف
/// - QR للتحقق لاحقاً
/// ============================================================

class DigitalDocument {
  // ============================================================
  // الهوية
  // ============================================================

  final String id;

  /// عنوان المستند
  String title;

  /// وصف المستند
  String description;

  /// اسم الملف الأصلي إن وجد
  String fileName;

  /// امتداد الملف
  String fileExtension;

  // ============================================================
  // بيانات المالك
  // ============================================================

  /// اسم صاحب المستند
  String ownerName;

  /// معرف MOX لصاحب المستند
  String ownerMoxId;

  /// رقم الهاتف المرتبط بالحساب
  String ownerPhone;

  // ============================================================
  // بيانات التوقيع
  // ============================================================

  /// التوقيع اليدوي المرسوم وتحويله إلى Base64
  String signatureImageBase64;

  /// البصمة الرقمية للمستند
  ///
  /// سيتم توليدها لاحقاً بواسطة SHA-256.
  String documentHash;

  /// التوقيع التشفيري الحقيقي
  ///
  /// سيتم توليده لاحقاً بواسطة DigitalSignatureService.
  String digitalSignature;

  /// المفتاح العام المستخدم للتحقق
  String publicKey;

  // ============================================================
  // التواريخ
  // ============================================================

  /// تاريخ إنشاء المستند
  DateTime createdAt;

  /// تاريخ التوقيع
  DateTime? signedAt;

  // ============================================================
  // الحالة
  // ============================================================

  /// هل تم التوقيع؟
  bool isSigned;

  /// هل تم اعتماد المستند؟
  bool isApproved;

  /// هل تم التحقق من صحة التوقيع؟
  bool isVerified;

  /// حالة المستند
  ///
  /// draft
  /// signed
  /// verified
  /// revoked
  String status;

  // ============================================================
  // معلومات المصدر
  // ============================================================

  /// هل المستند مستقل أم تم رفع ملف؟
  bool isIndependentDocument;

  /// نوع المصدر:
  ///
  /// independent
  /// uploaded
  String sourceType;

  // ============================================================
  // بيانات إضافية
  // ============================================================

  /// إصدار نظام التوقيع
  String signatureVersion;

  /// بيانات إضافية مستقبلية
  Map<String, dynamic> metadata;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  DigitalDocument({
    String? id,
    required this.title,
    this.description = '',
    this.fileName = '',
    this.fileExtension = '',
    this.ownerName = '',
    this.ownerMoxId = '',
    this.ownerPhone = '',
    this.signatureImageBase64 = '',
    this.documentHash = '',
    this.digitalSignature = '',
    this.publicKey = '',
    DateTime? createdAt,
    this.signedAt,
    this.isSigned = false,
    this.isApproved = false,
    this.isVerified = false,
    this.status = 'draft',
    this.isIndependentDocument = true,
    this.sourceType = 'independent',
    this.signatureVersion = 'MOX-DS-1.0',
    Map<String, dynamic>? metadata,
  }) : id = id ?? _generateId(),
       createdAt = createdAt ?? DateTime.now(),
       metadata = metadata ?? {};

  // ============================================================
  // ID GENERATOR
  // ============================================================

  static String _generateId() {
    final now = DateTime.now();

    return 'MOX-DOC-'
        '${now.microsecondsSinceEpoch}';
  }

  // ============================================================
  // FACTORY FROM JSON
  // ============================================================

  factory DigitalDocument.fromJson(Map<String, dynamic> json) {
    return DigitalDocument(
      id: json['id']?.toString(),

      title: json['title']?.toString() ?? '',

      description: json['description']?.toString() ?? '',

      fileName: json['fileName']?.toString() ?? '',

      fileExtension: json['fileExtension']?.toString() ?? '',

      ownerName: json['ownerName']?.toString() ?? '',

      ownerMoxId: json['ownerMoxId']?.toString() ?? '',

      ownerPhone: json['ownerPhone']?.toString() ?? '',

      signatureImageBase64: json['signatureImageBase64']?.toString() ?? '',

      documentHash: json['documentHash']?.toString() ?? '',

      digitalSignature: json['digitalSignature']?.toString() ?? '',

      publicKey: json['publicKey']?.toString() ?? '',

      createdAt: _parseDateTime(json['createdAt']),

      signedAt: _parseNullableDateTime(json['signedAt']),

      isSigned: _parseBool(json['isSigned']),

      isApproved: _parseBool(json['isApproved']),

      isVerified: _parseBool(json['isVerified']),

      status: json['status']?.toString() ?? 'draft',

      isIndependentDocument: json['isIndependentDocument'] == null
          ? true
          : _parseBool(json['isIndependentDocument']),

      sourceType: json['sourceType']?.toString() ?? 'independent',

      signatureVersion: json['signatureVersion']?.toString() ?? 'MOX-DS-1.0',

      metadata: _parseMetadata(json['metadata']),
    );
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory DigitalDocument.fromMap(Map<String, dynamic> map) {
    return DigitalDocument.fromJson(map);
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'title': title,

      'description': description,

      'fileName': fileName,

      'fileExtension': fileExtension,

      'ownerName': ownerName,

      'ownerMoxId': ownerMoxId,

      'ownerPhone': ownerPhone,

      'signatureImageBase64': signatureImageBase64,

      'documentHash': documentHash,

      'digitalSignature': digitalSignature,

      'publicKey': publicKey,

      'createdAt': createdAt.toIso8601String(),

      'signedAt': signedAt?.toIso8601String(),

      'isSigned': isSigned,

      'isApproved': isApproved,

      'isVerified': isVerified,

      'status': status,

      'isIndependentDocument': isIndependentDocument,

      'sourceType': sourceType,

      'signatureVersion': signatureVersion,

      'metadata': metadata,
    };
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return toJson();
  }

  // ============================================================
  // JSON STRING
  // ============================================================

  String toJsonString() {
    return jsonEncode(toJson());
  }

  // ============================================================
  // FROM JSON STRING
  // ============================================================

  factory DigitalDocument.fromJsonString(String source) {
    final dynamic decoded = jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException('بيانات المستند الرقمي غير صالحة');
    }

    return DigitalDocument.fromJson(Map<String, dynamic>.from(decoded));
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  DigitalDocument copyWith({
    String? id,
    String? title,
    String? description,
    String? fileName,
    String? fileExtension,
    String? ownerName,
    String? ownerMoxId,
    String? ownerPhone,
    String? signatureImageBase64,
    String? documentHash,
    String? digitalSignature,
    String? publicKey,
    DateTime? createdAt,
    DateTime? signedAt,
    bool? isSigned,
    bool? isApproved,
    bool? isVerified,
    String? status,
    bool? isIndependentDocument,
    String? sourceType,
    String? signatureVersion,
    Map<String, dynamic>? metadata,
  }) {
    return DigitalDocument(
      id: id ?? this.id,

      title: title ?? this.title,

      description: description ?? this.description,

      fileName: fileName ?? this.fileName,

      fileExtension: fileExtension ?? this.fileExtension,

      ownerName: ownerName ?? this.ownerName,

      ownerMoxId: ownerMoxId ?? this.ownerMoxId,

      ownerPhone: ownerPhone ?? this.ownerPhone,

      signatureImageBase64: signatureImageBase64 ?? this.signatureImageBase64,

      documentHash: documentHash ?? this.documentHash,

      digitalSignature: digitalSignature ?? this.digitalSignature,

      publicKey: publicKey ?? this.publicKey,

      createdAt: createdAt ?? this.createdAt,

      signedAt: signedAt ?? this.signedAt,

      isSigned: isSigned ?? this.isSigned,

      isApproved: isApproved ?? this.isApproved,

      isVerified: isVerified ?? this.isVerified,

      status: status ?? this.status,

      isIndependentDocument:
          isIndependentDocument ?? this.isIndependentDocument,

      sourceType: sourceType ?? this.sourceType,

      signatureVersion: signatureVersion ?? this.signatureVersion,

      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
    );
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  bool get hasSignature {
    return digitalSignature.isNotEmpty;
  }

  bool get hasDocumentHash {
    return documentHash.isNotEmpty;
  }

  bool get hasPublicKey {
    return publicKey.isNotEmpty;
  }

  bool get canBeVerified {
    return isSigned &&
        digitalSignature.isNotEmpty &&
        documentHash.isNotEmpty &&
        publicKey.isNotEmpty;
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'مسودة';

      case 'signed':
        return 'موقع';

      case 'verified':
        return 'موثق ومتحقق';

      case 'revoked':
        return 'ملغى';

      default:
        return 'غير معروف';
    }
  }

  // ============================================================
  // MARK AS SIGNED
  // ============================================================

  void markAsSigned({
    required String hash,
    required String signature,
    required String publicKey,
    String? signatureImage,
  }) {
    documentHash = hash;

    digitalSignature = signature;

    this.publicKey = publicKey;

    if (signatureImage != null) {
      signatureImageBase64 = signatureImage;
    }

    signedAt = DateTime.now();

    isSigned = true;

    isApproved = true;

    isVerified = false;

    status = 'signed';
  }

  // ============================================================
  // MARK VERIFIED
  // ============================================================

  void markAsVerified() {
    if (!canBeVerified) {
      return;
    }

    isVerified = true;

    status = 'verified';
  }

  // ============================================================
  // REVOKE
  // ============================================================

  void revoke() {
    isVerified = false;

    isApproved = false;

    status = 'revoked';
  }

  // ============================================================
  // METADATA
  // ============================================================

  void setMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  dynamic getMetadata(String key) {
    return metadata[key];
  }

  // ============================================================
  // PARSERS
  // ============================================================

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return false;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Map<String, dynamic> _parseMetadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // DEBUG / DISPLAY
  // ============================================================

  @override
  String toString() {
    return 'DigitalDocument('
        'id: $id, '
        'title: $title, '
        'ownerMoxId: $ownerMoxId, '
        'status: $status, '
        'isSigned: $isSigned, '
        'isVerified: $isVerified'
        ')';
  }
}
