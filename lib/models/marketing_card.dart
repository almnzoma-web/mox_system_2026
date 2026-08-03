class MarketingCard {
  String title, description, whatsapp, facebookUrl;
  double price;
  bool isApproved;

  MarketingCard({
    required this.title,
    required this.description,
    required this.whatsapp,
    required this.facebookUrl,
    this.price = 0.0,
    this.isApproved = false,
  });

  // دالة مساعدة ذكية لتحويل السعر القادم من JSON (سواء كان نصاً يحوي فواصل مثل "210,000" أو رقماً مباشراً مثل 210000)
  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // إزالة الفواصل والعلامات غير الرقمية لتحويل النص إلى رقم بشكل صحيح
      String cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanValue) ?? 0.0;
    }
    return 0.0;
  }

  // 1. تحويل الكائن إلى Map
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'whatsapp': whatsapp,
    'facebookUrl': facebookUrl,
    'price': price,
    'isApproved': isApproved,
  };

  // 2. إنشاء كائن من Map مع دعم الصيغتين للسعر
  factory MarketingCard.fromJson(Map<String, dynamic> json) => MarketingCard(
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    whatsapp: json['whatsapp'] ?? '',
    facebookUrl: json['facebookUrl'] ?? '',
    price: _parsePrice(json['price']),
    isApproved: json['isApproved'] ?? false,
  );

  // 3. 🌟 إضافة دالة copyWith السيادية لتحديث خصائص البطاقة بدقة
  MarketingCard copyWith({
    String? title,
    String? description,
    String? whatsapp,
    String? facebookUrl,
    double? price,
    bool? isApproved,
  }) {
    return MarketingCard(
      title: title ?? this.title,
      description: description ?? this.description,
      whatsapp: whatsapp ?? this.whatsapp,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      price: price ?? this.price,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}
