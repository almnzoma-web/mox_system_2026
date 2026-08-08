class MarketingCard {
  final String? id;

  String title;
  String description;
  String whatsapp;
  String facebookUrl;
  String category;

  String iconKey;

  double price;
  bool isApproved;

  MarketingCard({
    this.id,
    required this.title,
    required this.description,
    required this.whatsapp,
    required this.facebookUrl,
    this.category = 'بطاقة',
    this.iconKey = 'other',
    this.price = 0.0,
    this.isApproved = false,
  });

  // ============================================================
  // الرموز الرسمية
  // ============================================================

  static const Map<String, String> iconLabels = {
    'store': 'متجر وتجارة',
    'food': 'مطاعم وأطعمة',
    'service': 'خدمات',
    'education': 'تعليم',
    'health': 'صحة',
    'technology': 'تقنية',
    'fashion': 'أزياء',
    'other': 'أخرى',
  };

  static const Map<String, String> iconSymbols = {
    'store': '🏪',
    'food': '🍔',
    'service': '🛠️',
    'education': '🎓',
    'health': '❤️',
    'technology': '💻',
    'fashion': '👗',
    'other': '⭐',
  };

  // ============================================================
  // NORMALIZE ICON
  // ============================================================

  static String normalizeIconKey(dynamic value) {
    final key = value?.toString().trim().toLowerCase() ?? '';

    if (iconSymbols.containsKey(key)) {
      return key;
    }

    return 'other';
  }

  // ============================================================
  // ICON SYMBOL
  // ============================================================

  String get iconSymbol {
    return iconSymbols[normalizeIconKey(iconKey)] ?? '⭐';
  }

  // ============================================================
  // ICON LABEL
  // ============================================================

  String get iconLabel {
    return iconLabels[normalizeIconKey(iconKey)] ?? 'أخرى';
  }

  // ============================================================
  // PRICE PARSER
  // ============================================================

  static double _parsePrice(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      var val = value.trim();

      if (val.isEmpty) {
        return 0.0;
      }

      val = val.replaceAll(RegExp(r'[^\d.,-]'), '');

      // إزالة فواصل الآلاف
      if (val.contains(',')) {
        val = val.replaceAll(',', '');
      }

      return double.tryParse(val) ?? 0.0;
    }

    return 0.0;
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,

      'title': title,
      'description': description,

      'whatsapp': whatsapp,
      'facebookUrl': facebookUrl,

      'category': category,

      'iconKey': normalizeIconKey(iconKey),

      'price': price,

      'isApproved': isApproved,
    };
  }

  // ============================================================
  // FROM JSON
  // ============================================================

  factory MarketingCard.fromJson(Map<String, dynamic> json) {
    return MarketingCard(
      id: json['id']?.toString(),

      title: json['title']?.toString() ?? '',

      description: json['description']?.toString() ?? '',

      whatsapp: json['whatsapp']?.toString() ?? '',

      facebookUrl:
          json['facebookUrl']?.toString() ?? json['facebook']?.toString() ?? '',

      category: json['category']?.toString() ?? 'بطاقة',

      iconKey: normalizeIconKey(json['iconKey']),

      price: _parsePrice(json['price']),

      isApproved:
          json['isApproved'] == true ||
          json['isApproved']?.toString().toLowerCase() == 'true',
    );
  }

  factory MarketingCard.fromMap(Map<String, dynamic> map) {
    return MarketingCard.fromJson(map);
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  MarketingCard copyWith({
    String? id,
    String? title,
    String? description,
    String? whatsapp,
    String? facebookUrl,
    String? category,
    String? iconKey,
    double? price,
    bool? isApproved,
  }) {
    return MarketingCard(
      id: id ?? this.id,

      title: title ?? this.title,

      description: description ?? this.description,

      whatsapp: whatsapp ?? this.whatsapp,

      facebookUrl: facebookUrl ?? this.facebookUrl,

      category: category ?? this.category,

      iconKey: iconKey ?? this.iconKey,

      price: price ?? this.price,

      isApproved: isApproved ?? this.isApproved,
    );
  }

  // ============================================================
  // WRITE OPERATOR
  // ============================================================

  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'title':
        title = value?.toString() ?? '';
        break;

      case 'description':
        description = value?.toString() ?? '';
        break;

      case 'whatsapp':
        whatsapp = value?.toString() ?? '';
        break;

      case 'facebookUrl':
      case 'facebook':
        facebookUrl = value?.toString() ?? '';
        break;

      case 'category':
        category = value?.toString() ?? 'بطاقة';
        break;

      case 'iconKey':
        iconKey = normalizeIconKey(value);
        break;

      case 'price':
        price = _parsePrice(value);
        break;

      case 'isApproved':
        isApproved = value == true || value?.toString().toLowerCase() == 'true';
        break;
    }
  }

  // ============================================================
  // READ OPERATOR
  // ============================================================

  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;

      case 'title':
        return title;

      case 'description':
        return description;

      case 'whatsapp':
        return whatsapp;

      case 'facebookUrl':
        return facebookUrl;

      case 'category':
        return category;

      case 'iconKey':
        return normalizeIconKey(iconKey);

      case 'price':
        return price;

      case 'isApproved':
        return isApproved;

      default:
        return null;
    }
  }
}
