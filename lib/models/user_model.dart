import 'dart:convert';
import '../models/marketing_card.dart';

class UserModel {
  String phone, password;
  String name;
  String address;
  String storeDescription; // 🌟 حقل وصف المتجر العام المستقل
  String gender, accountType, moxId, role;
  String? customWhatsApp;
  String? guardianMoxId;
  String? guardianMoxIdCustomer;
  String? storePublishDate;
  String? activationDate;
  double balance, commission;
  int points;
  List<MarketingCard> myAssets;

  UserModel({
    required this.phone,
    required this.password,
    required this.name,
    required this.address,
    this.storeDescription = '', // القيمة الافتراضية فارغة
    required this.balance,
    this.commission = 0.0,
    required this.gender,
    required this.accountType,
    this.moxId = "ID-005000",
    this.role = "free",
    this.customWhatsApp,
    this.guardianMoxId = "",
    this.guardianMoxIdCustomer = "MOX249-00010001",
    this.storePublishDate,
    this.activationDate,
    this.points = 0,
    this.myAssets = const [],
  });

  UserModel copyWith({
    int? points,
    double? balance,
    double? commission,
    String? name,
    String? address,
    String? storeDescription, // 🌟 إضافته هنا في الـ copyWith
    String? phone,
    String? role, // 🌟 إضافة role هنا لحل المشكلة بالمسطرة
    String? guardianMoxId,
    String? guardianMoxIdCustomer,
    String? storePublishDate,
    String? activationDate,
    List<MarketingCard>? myAssets,
  }) {
    return UserModel(
      phone: phone ?? this.phone,
      password: password,
      name: name ?? this.name,
      address: address ?? this.address,
      storeDescription: storeDescription ?? this.storeDescription, // 🌟 تحديثه
      balance: balance ?? this.balance,
      commission: commission ?? this.commission,
      gender: gender,
      accountType: accountType,
      moxId: moxId,
      role: role ?? this.role, // 🌟 تحديث role هنا
      customWhatsApp: customWhatsApp,
      guardianMoxId: guardianMoxId ?? this.guardianMoxId,
      guardianMoxIdCustomer:
          guardianMoxIdCustomer ?? this.guardianMoxIdCustomer,
      storePublishDate: storePublishDate ?? this.storePublishDate,
      activationDate: activationDate ?? this.activationDate,
      points: points ?? this.points,
      myAssets: myAssets ?? this.myAssets,
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'password': password,
    'name': name,
    'address': address,
    'storeDescription': storeDescription, // 🌟 حفظه في الـ JSON
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
    'activationDate': activationDate ?? storePublishDate ?? '',
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

    String? pubDate = json['storePublishDate']?.toString();
    String? actDate = json['activationDate']?.toString();
    String? finalDate = (pubDate != null && pubDate.isNotEmpty)
        ? pubDate
        : actDate;

    return UserModel(
      phone: json['phone']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      storeDescription:
          json['storeDescription']?.toString() ?? '', // 🌟 قراءته من الـ JSON
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
      storePublishDate: finalDate,
      activationDate: finalDate,
    );
  }
}
