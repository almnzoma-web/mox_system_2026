import 'dart:convert';
import '../models/marketing_model.dart';

class UserModel {
  String phone, password;
  String name;
  String address;
  String gender, accountType, moxId, role;
  String? customWhatsApp;
  String? guardianMoxId; // رقم الوصي (المرشد)
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
    this.moxId = "لم يحدد",
    this.role = "free",
    this.customWhatsApp,
    this.guardianMoxId = "MOX249-00010001", // القيمة الافتراضية للمدير
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
      guardianMoxId: guardianMoxId,
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
    'customWhatsApp': customWhatsApp,
    'guardianMoxId': guardianMoxId,
    'points': points,
    'myAssets': myAssets.map((e) => e.toJson()).toList(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    phone: json['phone'] ?? '',
    password: json['password'] ?? '',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    balance: (json['balance'] as num? ?? 0.0).toDouble(),
    commission: (json['commission'] as num? ?? 0.0).toDouble(),
    gender: json['gender'] ?? '',
    accountType: json['accountType'] ?? '',
    moxId: json['moxId'] ?? "لم يحدد",
    role: json['role'] ?? "free",
    customWhatsApp: json['customWhatsApp'],
    guardianMoxId: json['guardianMoxId'] ?? "MOX249-00010001",
    points: json['points'] ?? 0,
    myAssets: (json['myAssets'] as List? ?? [])
        .map((e) => MarketingCard.fromJson(e))
        .toList(),
  );

  // ==========================================
  // الدوال السيادية الخاصة بـ SQLite (الجديدة)
  // ==========================================
  Map<String, dynamic> toMap() => {
    'phone': phone,
    'moxId': moxId,
    'password': password,
    'name': name,
    'address': address,
    'balance': balance,
    'commission': commission,
    'gender': gender,
    'accountType': accountType,
    'role': role,
    'customWhatsApp': customWhatsApp,
    'guardianMoxId': guardianMoxId,
    'points': points,
    'myAssets': jsonEncode(myAssets.map((e) => e.toJson()).toList()),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    List<MarketingCard> parsedAssets = [];
    try {
      if (map['myAssets'] != null && map['myAssets'].toString().isNotEmpty) {
        List<dynamic> decodedList = jsonDecode(map['myAssets']);
        parsedAssets = decodedList
            .map((e) => MarketingCard.fromJson(e))
            .toList();
      }
    } catch (_) {
      parsedAssets = [];
    }

    return UserModel(
      phone: map['phone'] ?? '',
      moxId: map['moxId'] ?? "لم يحدد",
      password: map['password'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      balance: (map['balance'] as num? ?? 0.0).toDouble(),
      commission: (map['commission'] as num? ?? 0.0).toDouble(),
      gender: map['gender'] ?? '',
      accountType: map['accountType'] ?? '',
      role: map['role'] ?? "free",
      customWhatsApp: map['customWhatsApp'],
      guardianMoxId: map['guardianMoxId'] ?? "MOX249-00010001",
      points: map['points'] ?? 0,
      myAssets: parsedAssets,
    );
  }
}
