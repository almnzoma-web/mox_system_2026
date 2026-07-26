import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// تعريف كلاس المنتج (يجب أن يكون هنا أو في ملف models/product_model.dart)
class ProductModel {
  final String id;
  final String title;
  final String category;
  final double? priceSDG;
  final double? priceDollarOwnership;
  final double? priceDollarSubscription;

  const ProductModel({
    required this.id,
    required this.title,
    required this.category,
    this.priceSDG,
    this.priceDollarOwnership,
    this.priceDollarSubscription,
  });
}

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  final List<ProductModel> myProducts = const [
    ProductModel(
      id: "1",
      title: "موقع محتوى",
      category: "Product",
      priceSDG: 50.0,
    ),
    ProductModel(
      id: "2",
      title: "تطبيق محاسبة",
      category: "App",
      priceDollarOwnership: 100.0,
      priceDollarSubscription: 10.0,
    ),
    ProductModel(
      id: "3",
      title: "متجر إلكتروني",
      category: "Product",
      priceSDG: 75.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("متجر MOX"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
        ),
        itemCount: myProducts.length,
        itemBuilder: (context, index) {
          final p = myProducts[index];
          return Card(
            elevation: 8,
            child: Column(
              children: [
                const Icon(
                  Icons.business_center,
                  size: 50,
                  color: Colors.amber,
                ),
                Text(
                  p.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => p.category == 'App'
                      ? _handleAppFlow(context, p.title)
                      : _handleSiteFlow(p.title),
                  child: Text(p.category == 'App' ? "طلب تطبيق" : "طلب موقع"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSiteFlow(String title) async {
    final Uri url = Uri.parse(
      "https://wa.me/249115855164?text=طلب+موقع:+${title.replaceAll(' ', '+')}",
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _handleAppFlow(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text("طلب تطبيق"),
        content: Text("جاري التواصل..."),
      ),
    );
  }
}
