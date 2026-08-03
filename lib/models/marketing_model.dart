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

  // 1. تحويل الكائن إلى Map
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'whatsapp': whatsapp,
    'facebookUrl': facebookUrl,
    'price': price,
    'isApproved': isApproved,
  };

  // 2. إنشاء كائن من Map
  factory MarketingCard.fromJson(Map<String, dynamic> json) => MarketingCard(
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    whatsapp: json['whatsapp'] ?? '',
    facebookUrl: json['facebookUrl'] ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
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
