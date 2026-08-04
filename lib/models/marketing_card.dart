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

  // 🌟 دالة مساعدة ذكية ومحدثة لمعالجة الأسعار والتحويل بدقة مطلقة
  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      String val = value.trim();
      if (val.isEmpty) return 0.0;

      // تنظيف النص مع الاحتفاظ بالأرقام والنقاط والفواصل
      val = val.replaceAll(RegExp(r'[^\d.,]'), '');

      // معالجة الفواصل الخاصة بالآلاف أو الكسور العشرية
      if (val.contains(',')) {
        val = val.replaceAll(',', '');
      }

      return double.tryParse(val) ?? 0.0;
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

  // 3. 🌟 دالة copyWith السيادية لتحديث خصائص البطاقة بدقة
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
