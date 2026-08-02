import 'dart:convert';
import '../models/marketing_model.dart';

class UserModel {
  String phone, password;
  String name;
  String address;
  String gender, accountType, moxId, role;
  String? customWhatsApp;
  String? guardianMoxId; // حقل الوصي الأصلي الخاص بموكس (يظل خالياً للعميل)
  String?
  guardianMoxIdCustomer; // الحقل الجديد: وصي العميل الجديد أو المدير افتراضياً
  String? storePublishDate; // حقل تاريخ أول نشر لتثبيت فترة الـ 365 يوماً
  double balance, commission;
  int points; // نقاط الإحالة
  List<MarketingCard> myAssets;

  UserModel({
    required this.phone,
    required this.password,
    required this.name,
    required this.address,
    required this.balance,
    this.commission = 0.0,
    required this.gender,
    required this.accountType,
    this.moxId = "ID-005000",
    this.role = "free",
    this.customWhatsApp,
    this.guardianMoxId = "", // يظل خالياً افتراضياً للعميل
    this.guardianMoxIdCustomer = "MOX249-00010001", // القيمة الافتراضية للمدير
    this.storePublishDate,
    this.points = 0,
    this.myAssets = const [],
  });

  // دالة آمنة لتحديث بيانات المستخدم دون المساس ببقية الكود
  UserModel copyWith({
    int? points,
    double? balance,
    double? commission,
    String? name,
    String? address,
    String? guardianMoxId,
    String? guardianMoxIdCustomer,
    String? storePublishDate,
    List<MarketingCard>? myAssets,
  }) {
    return UserModel(
      phone: phone,
      password: password,
      name: name ?? this.name,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      commission: commission ?? this.commission,
      gender: gender,
      accountType: accountType,
      moxId: moxId,
      role: role,
      customWhatsApp: customWhatsApp,
      guardianMoxId: guardianMoxId ?? this.guardianMoxId,
      guardianMoxIdCustomer:
          guardianMoxIdCustomer ?? this.guardianMoxIdCustomer,
      storePublishDate: storePublishDate ?? this.storePublishDate,
      points: points ?? this.points,
      myAssets: myAssets ?? this.myAssets,
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'password': password,
    'name': name,
    'address': address,
    'balance': balance,
    'commission': commission,
    'gender': gender,
    'accountType': accountType,
    'moxId': moxId,
    'role': role,
    'customWhatsApp': customWhatsApp ?? '',
    'guardianMoxId': guardianMoxId ?? '',
    'points': points,
    'myAssets': jsonEncode(myAssets.map((e) => e.toJson()).toList()),
    'guardianMoxIdCustomer': guardianMoxIdCustomer ?? '',
    'storePublishDate': storePublishDate ?? '',
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<MarketingCard> parsedAssets = [];
    try {
      var rawAssets = json['myAssets'];
      if (rawAssets != null) {
        if (rawAssets is String && rawAssets.isNotEmpty) {
          List<dynamic> decodedList = jsonDecode(rawAssets);
          parsedAssets = decodedList
              .map((e) => MarketingCard.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (rawAssets is List) {
          parsedAssets = rawAssets
              .map((e) => MarketingCard.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      parsedAssets = [];
    }

    return UserModel(
      phone: json['phone']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0.0,
      gender: json['gender']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? '',
      moxId: json['moxId']?.toString() ?? "لم يحدد",
      role: json['role']?.toString() ?? "free",
      customWhatsApp: json['customWhatsApp']?.toString(),
      guardianMoxId: json['guardianMoxId']?.toString() ?? "",
      points: int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      myAssets: parsedAssets,
      guardianMoxIdCustomer:
          json['guardianMoxIdCustomer']?.toString() ?? "MOX249-00010001",
      storePublishDate: json['storePublishDate']?.toString(),
    );
  }
}
