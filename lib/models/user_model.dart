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
    // ----------------------------------------------------------
    // الحساب
    // ----------------------------------------------------------
    int? points,
    double? balance,
    double? commission,

    String? phone,

    // 🔐 مهم جداً:
    // أضفنا password هنا حتى نستطيع حماية كلمة السر
    // وعدم استبدالها بقيمة فارغة.
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

    // ----------------------------------------------------------
    // التوقيع الرقمي
    // ----------------------------------------------------------
    String? digitalPublicKey,
    String? digitalSignatureAlgorithm,
    String? digitalSignatureCreatedAt,
    int? digitalSignatureKeyVersion,
  }) {
    return UserModel(
      phone: phone ?? this.phone,

      // 🔐 إذا لم نرسل password:
      // احتفظ بكلمة السر القديمة.
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

      // 🔐 مهم:
      // المحافظة على المستندات الموقعة.
      signedDocuments: signedDocuments ?? this.signedDocuments,

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
    // ✨ ضمان أن activationDate ينسخ
    // storePublishDate تلقائياً إذا لم يكن موجوداً.

    final String effectiveActivation =
        (activationDate != null &&
            activationDate!.trim().isNotEmpty &&
            activationDate != 'null')
        ? activationDate!
        : (storePublishDate ?? '');

    return {
      'phone': phone,

      // 🔐 كلمة السر محفوظة كما هي.
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

      'storePublishDate': storePublishDate ?? '',

      'activationDate': effectiveActivation,

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
    // ==========================================================
    // FIND KEY
    // ==========================================================

    T? findKey<T>(List<String> keys) {
      for (final String key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          final dynamic val = json[key];

          if (val is T) {
            return val;
          }

          if (T == String) {
            return val.toString() as T;
          }
        }
      }

      for (final MapEntry<String, dynamic> entry in json.entries) {
        for (final String key in keys) {
          if (entry.key.toLowerCase() == key.toLowerCase() &&
              entry.value != null) {
            final dynamic val = entry.value;

            if (T == String) {
              return val.toString() as T;
            }

            return val as T;
          }
        }
      }

      return null;
    }

    // ==========================================================
    // MARKETING ASSETS (معالجة آمنة تمنع الحذف)
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

    // 💡 الحماية الذكية: إذا جاءت القائمة الجديدة فارغة، يمكنك تمرير الكاش القديم إن وجد،
    // أو إذا كنا نريد حمايتها تلقائياً من الـ Json الفارغ:
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
    // DATES
    // ==========================================================

    final String? rawPublishDate = findKey<String>([
      'storePublishDate',
      'storepublishdate',
      'STORE_PUBLISH_DATE',
    ])?.trim();

    final String? rawActivationDate = findKey<String>([
      'activationDate',
      'activationdate',
      'ACTIVATION_DATE',
    ])?.trim();

    final String? finalPublishDate =
        rawPublishDate != null &&
            rawPublishDate.isNotEmpty &&
            rawPublishDate != 'null'
        ? rawPublishDate
        : null;

    final String? finalActivationDate =
        rawActivationDate != null &&
            rawActivationDate.isNotEmpty &&
            rawActivationDate != 'null'
        ? rawActivationDate
        : finalPublishDate;

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

    final String? rawSignatureCreatedAt = json['digitalSignatureCreatedAt']
        ?.toString()
        .trim();

    final String? signatureCreatedAt =
        rawSignatureCreatedAt != null &&
            rawSignatureCreatedAt.isNotEmpty &&
            rawSignatureCreatedAt != 'null'
        ? rawSignatureCreatedAt
        : null;

    final String algorithm =
        json['digitalSignatureAlgorithm']?.toString().trim().isNotEmpty == true
        ? json['digitalSignatureAlgorithm'].toString()
        : 'Ed25519';

    final int keyVersion =
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
