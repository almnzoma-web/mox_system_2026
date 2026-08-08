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

  /// تاريخ إنشاء هوية التوقيع الرقمي.
  String? digitalSignatureCreatedAt;

  /// رقم إصدار مفتاح التوقيع.
  ///
  /// يسمح لنا مستقبلاً بتغيير المفتاح دون كسر
  /// المستندات القديمة.
  int digitalSignatureKeyVersion;

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

    String? name,
    String? address,
    String? storeDescription,

    String? phone,
    String? role,

    String? guardianMoxId,
    String? guardianMoxIdCustomer,

    String? storePublishDate,
    String? activationDate,

    List<MarketingCard>? myAssets,

    // ==========================================================
    // التوقيع الرقمي
    // ==========================================================
    String? digitalPublicKey,
    String? digitalSignatureAlgorithm,
    String? digitalSignatureCreatedAt,
    int? digitalSignatureKeyVersion,
  }) {
    return UserModel(
      phone: phone ?? this.phone,

      // لا يتم تغيير كلمة السر هنا
      password: password,

      name: name ?? this.name,

      address: address ?? this.address,

      storeDescription: storeDescription ?? this.storeDescription,

      balance: balance ?? this.balance,

      commission: commission ?? this.commission,

      gender: gender,

      accountType: accountType,

      moxId: moxId,

      role: role ?? this.role,

      customWhatsApp: customWhatsApp,

      guardianMoxId: guardianMoxId ?? this.guardianMoxId,

      guardianMoxIdCustomer:
          guardianMoxIdCustomer ?? this.guardianMoxIdCustomer,

      storePublishDate: storePublishDate ?? this.storePublishDate,

      activationDate: activationDate ?? this.activationDate,

      points: points ?? this.points,

      myAssets: myAssets ?? this.myAssets,

      // ========================================================
      // التوقيع الرقمي
      // ========================================================
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
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,

      // للمستخدمين العاديين فقط.
      // الإدارة في Flutter تحمل كلمة سر فارغة.
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

      'storePublishDate': storePublishDate ?? '',

      'activationDate': activationDate ?? '',

      // ========================================================
      // الهوية الرقمية
      // ========================================================
      'digitalPublicKey': digitalPublicKey ?? '',

      'digitalSignatureAlgorithm': digitalSignatureAlgorithm,

      'digitalSignatureCreatedAt': digitalSignatureCreatedAt ?? '',

      'digitalSignatureKeyVersion': digitalSignatureKeyVersion,
    };
  }

  // ============================================================
  // FROM JSON
  // ============================================================

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final List<MarketingCard> parsedAssets = [];

    try {
      final rawAssets = json['myAssets'];

      if (rawAssets is String && rawAssets.trim().isNotEmpty) {
        final decoded = jsonDecode(rawAssets);

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
    // DATES
    // ==========================================================

    final rawPublishDate = json['storePublishDate']?.toString().trim();

    final rawActivationDate = json['activationDate']?.toString().trim();

    final String? publishDate =
        rawPublishDate != null &&
            rawPublishDate.isNotEmpty &&
            rawPublishDate != 'null'
        ? rawPublishDate
        : null;

    final String? activationDate =
        rawActivationDate != null &&
            rawActivationDate.isNotEmpty &&
            rawActivationDate != 'null'
        ? rawActivationDate
        : null;

    // ==========================================================
    // الهوية الرقمية
    // ==========================================================

    final rawPublicKey = json['digitalPublicKey']?.toString().trim();

    final String? publicKey =
        rawPublicKey != null &&
            rawPublicKey.isNotEmpty &&
            rawPublicKey != 'null'
        ? rawPublicKey
        : null;

    final rawSignatureCreatedAt = json['digitalSignatureCreatedAt']
        ?.toString()
        .trim();

    final String? signatureCreatedAt =
        rawSignatureCreatedAt != null &&
            rawSignatureCreatedAt.isNotEmpty &&
            rawSignatureCreatedAt != 'null'
        ? rawSignatureCreatedAt
        : null;

    final algorithm =
        json['digitalSignatureAlgorithm']?.toString().trim().isNotEmpty == true
        ? json['digitalSignatureAlgorithm'].toString()
        : 'Ed25519';

    final keyVersion =
        int.tryParse(json['digitalSignatureKeyVersion']?.toString() ?? '1') ??
        1;

    // ==========================================================
    // USER
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

      storePublishDate: publishDate,

      activationDate: activationDate,

      points: int.tryParse(json['points']?.toString() ?? '0') ?? 0,

      myAssets: parsedAssets,

      // ========================================================
      // الهوية الرقمية
      // ========================================================
      digitalPublicKey: publicKey,

      digitalSignatureAlgorithm: algorithm,

      digitalSignatureCreatedAt: signatureCreatedAt,

      digitalSignatureKeyVersion: keyVersion,
    );
  }
}
