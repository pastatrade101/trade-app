class Product {
  final String id;
  final String title;
  final double price;
  final String currency;
  final String billingPeriod;
  final bool isActive;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.billingPeriod,
    required this.isActive,
  });

  factory Product.fromJson(String id, Map<String, dynamic> json) {
    return Product(
      id: id,
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'TZS',
      billingPeriod: json['billingPeriod'] ?? 'monthly',
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': id,
      'title': title,
      'price': price,
      'currency': currency,
      'billingPeriod': billingPeriod,
      'isActive': isActive,
    };
  }
}
