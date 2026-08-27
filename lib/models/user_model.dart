import 'dart:convert';

import '../models/marketing_card.dart';
import '../models/signed_document.dart';

class UserModel {
  String phone;
  String password;

  String name;
  String address;

  String storeDescription;

  String gender;
  String accountType;

  String moxId;
  String role;

  String? customWhatsApp;

  String? guardianMoxId;
  String? guardianMoxIdCustomer;

  String? storePublishDate;
  String? activationDate;

  double balance;
  double commission;

  int points;

  List<MarketingCard> myAssets;
  List<SignedDocument> signedDocuments;

  // ============================================================
  // الهوية الرقمية للتوقيع
  // ============================================================

  /// المفتاح العام للمستخدم.
  ///
  /// مهم:
  /// المفتاح الخاص لا يتم تخزينه هنا.
  String? digitalPublicKey;

  /// الخوارزمية المستخدمة في التوقيع.
  /// القيمة الحالية:
  /// Ed25519
  String digitalSignatureAlgorithm;

  /// تاريخ إنشاء هوية التوقيع الرقمي (بالأيام فقط).
  String? digitalSignatureCreatedAt;

  /// رقم إصدار مفتاح التوقيع.
  ///
  /// يسمح لنا مستقبلاً بتغيير المفتاح دون كسر
  /// المستندات القديمة.
  int digitalSignatureKeyVersion;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  UserModel({
    required this.phone,
    required this.password,
    required this.name,
    required this.address,
    this.storeDescription = '',
    required this.balance,
    this.commission = 0.0,
    required this.gender,
    required this.accountType,
    this.moxId = 'ID-005000',
    this.role = 'free',
    this.customWhatsApp,
    this.guardianMoxId = '',
    this.guardianMoxIdCustomer = 'MOX249-00010001',
    this.storePublishDate,
    this.activationDate,
    this.points = 0,
    this.myAssets = const [],
    this.signedDocuments = const [],

    // ==========================================================
    // التوقيع الرقمي
    // ==========================================================
    this.digitalPublicKey,
    this.digitalSignatureAlgorithm = 'Ed25519',
    this.digitalSignatureCreatedAt,
    this.digitalSignatureKeyVersion = 1,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  UserModel copyWith({
    int? points,
    double? balance,
    double? commission,
    String? phone,
    String? password,
    String? name,
    String? address,
    String? storeDescription,
    String? gender,
    String? accountType,
    String? moxId,
    String? role,
    String? customWhatsApp,
    String? guardianMoxId,
    String? guardianMoxIdCustomer,
    String? storePublishDate,
    String? activationDate,
    List<MarketingCard>? myAssets,
    List<SignedDocument>? signedDocuments,
    String? digitalPublicKey,
    String? digitalSignatureAlgorithm,
    String? digitalSignatureCreatedAt,
    int? digitalSignatureKeyVersion,
  }) {
    return UserModel(
      phone: phone ?? this.phone,
      password: password ?? this.password,
      name: name ?? this.name,
      address: address ?? this.address,
      storeDescription: storeDescription ?? this.storeDescription,
      balance: balance ?? this.balance,
      commission: commission ?? this.commission,
      gender: gender ?? this.gender,
      accountType: accountType ?? this.accountType,
      moxId: moxId ?? this.moxId,
      role: role ?? this.role,
      customWhatsApp: customWhatsApp ?? this.customWhatsApp,
      guardianMoxId: guardianMoxId ?? this.guardianMoxId,
      guardianMoxIdCustomer:
          guardianMoxIdCustomer ?? this.guardianMoxIdCustomer,
      storePublishDate: storePublishDate ?? this.storePublishDate,
      activationDate: activationDate ?? this.activationDate,
      points: points ?? this.points,
      myAssets: myAssets ?? this.myAssets,
      signedDocuments: signedDocuments ?? this.signedDocuments,
      digitalPublicKey: digitalPublicKey ?? this.digitalPublicKey,
      digitalSignatureAlgorithm:
          digitalSignatureAlgorithm ?? this.digitalSignatureAlgorithm,
      digitalSignatureCreatedAt:
          digitalSignatureCreatedAt ?? this.digitalSignatureCreatedAt,
      digitalSignatureKeyVersion:
          digitalSignatureKeyVersion ?? this.digitalSignatureKeyVersion,
    );
  }

  // ============================================================
  // TO JSON (معدل خصيصاً لكي لا يرسل تواريخ النشر والتفعيل والجلسات للشيت)
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'password': password,
      'name': name,
      'address': address,
      'storeDescription': storeDescription,
      'balance': balance,
      'commission': commission,
      'gender': gender,
      'accountType': accountType,
      'moxId': moxId,
      'role': role,
      'customWhatsApp': customWhatsApp ?? '',
      'guardianMoxId': guardianMoxId ?? '',
      'guardianMoxIdCustomer': guardianMoxIdCustomer ?? '',
      'points': points,
      'myAssets': jsonEncode(myAssets.map((e) => e.toJson()).toList()),
      'signedDocuments': jsonEncode(
        signedDocuments.map((e) => e.toJson()).toList(),
      ),
      // ملاحظة: تم استبعاد storePublishDate و activationDate بناءً على التعليمات السيادية
      // لكي لا تطبع في الشيت وتسبب أزمة Vercel.

      // الهوية الرقمية الأساسية
      'digitalPublicKey': digitalPublicKey ?? '',
      'digitalSignatureAlgorithm': digitalSignatureAlgorithm,
      'digitalSignatureCreatedAt': digitalSignatureCreatedAt ?? '',
      'digitalSignatureKeyVersion': digitalSignatureKeyVersion,
    };
  }

  // ============================================================
  // FROM JSON (معالجة الأيام فقط بدون ساعات)
  // ============================================================

  factory UserModel.fromJson(Map<String, dynamic> json) {
    T? findKey<T>(List<String> keys) {
      for (final String key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          final dynamic val = json[key];
          if (val is T) return val;
          if (T == String) return val.toString() as T;
        }
      }

      for (final MapEntry<String, dynamic> entry in json.entries) {
        for (final String key in keys) {
          if (entry.key.toLowerCase() == key.toLowerCase() &&
              entry.value != null) {
            final dynamic val = entry.value;
            if (T == String) return val.toString() as T;
            return val as T;
          }
        }
      }
      return null;
    }

    // تنظيف التاريخ ليقتصر على الأيام فقط (قص أي جزء خاص بالساعات إن وجد مثل YYYY-MM-DD)
    String? cleanDate(String? raw) {
      if (raw == null || raw.trim().isEmpty || raw == 'null') return null;
      final trimmed = raw.trim();
      // إذا كان يحتوي على مسافة أو حرف T (ساعات)، نقوم بأخذ الجزء الخاص باليوم فقط قبلها
      if (trimmed.contains('T')) {
        return trimmed.split('T').first;
      }
      if (trimmed.contains(' ')) {
        return trimmed.split(' ').first;
      }
      return trimmed;
    }

    // ==========================================================
    // MARKETING ASSETS
    // ==========================================================
    final List<MarketingCard> parsedAssets = [];
    try {
      final dynamic rawAssets = findKey<dynamic>([
        'myAssets',
        'myassets',
        'MYASSETS',
        'my_assets',
      ]);
      if (rawAssets is String && rawAssets.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(rawAssets);
        if (decoded is List) {
          parsedAssets.addAll(
            decoded.whereType<Map>().map(
              (e) => MarketingCard.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
        }
      } else if (rawAssets is List) {
        parsedAssets.addAll(
          rawAssets.whereType<Map>().map(
            (e) => MarketingCard.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
    } catch (_) {}

    // ==========================================================
    // SIGNED DOCUMENTS
    // ==========================================================
    final List<SignedDocument> parsedSignedDocuments = [];
    try {
      final dynamic rawDocuments = findKey<dynamic>([
        'signedDocuments',
        'signeddocuments',
        'SIGNEDDOCUMENTS',
        'signed_documents',
      ]);
      if (rawDocuments is String && rawDocuments.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(rawDocuments);
        if (decoded is List) {
          parsedSignedDocuments.addAll(
            decoded.whereType<Map>().map(
              (e) => SignedDocument.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
        }
      } else if (rawDocuments is List) {
        parsedSignedDocuments.addAll(
          rawDocuments.whereType<Map>().map(
            (e) => SignedDocument.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
    } catch (_) {}

    // ==========================================================
    // DATES (أيام فقط بدون ساعات)
    // ==========================================================
    final String? rawPublishDate = cleanDate(
      findKey<String>([
        'storePublishDate',
        'storepublishdate',
        'STORE_PUBLISH_DATE',
      ]),
    );

    final String? rawActivationDate = cleanDate(
      findKey<String>(['activationDate', 'activationdate', 'ACTIVATION_DATE']),
    );

    final String? finalPublishDate = rawPublishDate;
    final String? finalActivationDate = rawActivationDate ?? finalPublishDate;

    // ==========================================================
    // DIGITAL IDENTITY
    // ==========================================================
    final String? rawPublicKey = json['digitalPublicKey']?.toString().trim();
    final String? publicKey =
        rawPublicKey != null &&
            rawPublicKey.isNotEmpty &&
            rawPublicKey != 'null'
        ? rawPublicKey
        : null;

    final String? rawSignatureCreatedAt = cleanDate(
      json['digitalSignatureCreatedAt']?.toString(),
    );
    final String? signatureCreatedAt = rawSignatureCreatedAt;

    final String algorithm =
        json['digitalSignatureAlgorithm']?.toString().trim().isNotEmpty == true
        ? json['digitalSignatureAlgorithm'].toString()
        : 'Ed25519';

    final int keyVersion =
        int.tryParse(json['digitalSignatureKeyVersion']?.toString() ?? '1') ??
        1;

    // ==========================================================
    // USER CONSTRUCTION
    // ==========================================================
    return UserModel(
      phone: json['phone']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      storeDescription: json['storeDescription']?.toString() ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0.0,
      gender: json['gender']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? '',
      moxId: json['moxId']?.toString() ?? 'لم يحدد',
      role: json['role']?.toString() ?? 'free',
      customWhatsApp: json['customWhatsApp']?.toString(),
      guardianMoxId: json['guardianMoxId']?.toString() ?? '',
      guardianMoxIdCustomer:
          json['guardianMoxIdCustomer']?.toString() ?? 'MOX249-00010001',
      storePublishDate: finalPublishDate,
      activationDate: finalActivationDate,
      points:
          int.tryParse(
            findKey<dynamic>([
                  'points',
                  'POINTS',
                  'Points',
                  'user_points',
                  'USER_POINTS',
                ])?.toString() ??
                '0',
          ) ??
          0,
      myAssets: parsedAssets,
      signedDocuments: parsedSignedDocuments,
      digitalPublicKey: publicKey,
      digitalSignatureAlgorithm: algorithm,
      digitalSignatureCreatedAt: signatureCreatedAt,
      digitalSignatureKeyVersion: keyVersion,
    );
  }
}
