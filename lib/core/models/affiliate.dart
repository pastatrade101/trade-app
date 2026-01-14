import '../utils/firestore_helpers.dart';

enum AffiliateCategory {
  forex,
  crypto,
  tools,
  education,
  brokers,
}

extension AffiliateCategoryX on AffiliateCategory {
  String get label {
    switch (this) {
      case AffiliateCategory.forex:
        return 'Forex';
      case AffiliateCategory.crypto:
        return 'Crypto';
      case AffiliateCategory.tools:
        return 'Tools';
      case AffiliateCategory.education:
        return 'Education';
      case AffiliateCategory.brokers:
        return 'Brokers';
    }
  }

  String get value => toString().split('.').last;

  static AffiliateCategory fromValue(String value) {
    return AffiliateCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => AffiliateCategory.tools,
    );
  }
}

class Affiliate {
  final String id;
  final String title;
  final AffiliateCategory category;
  final String shortDescription;
  final String? disclaimer;
  final String url;
  final String? logoUrl;
  final List<String> regions;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final int clickCount;
  final DateTime? lastClickedAt;

  const Affiliate({
    required this.id,
    required this.title,
    required this.category,
    required this.shortDescription,
    this.disclaimer,
    required this.url,
    this.logoUrl,
    required this.regions,
    required this.isActive,
    required this.isFeatured,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.clickCount,
    this.lastClickedAt,
  });

  factory Affiliate.fromJson(String id, Map<String, dynamic> json) {
    return Affiliate(
      id: id,
      title: json['title'] ?? '',
      category: AffiliateCategoryX.fromValue(json['category'] ?? ''),
      shortDescription: json['shortDescription'] ?? '',
      disclaimer: json['disclaimer'],
      url: json['url'] ?? '',
      logoUrl: json['logoUrl'],
      regions: List<String>.from(json['regions'] ?? const <String>[]),
      isActive: json['isActive'] ?? true,
      isFeatured: json['isFeatured'] ?? false,
      sortOrder: (json['sortOrder'] ?? 0).toInt(),
      createdAt: timestampToDate(json['createdAt']),
      updatedAt: timestampToDate(json['updatedAt']),
      createdBy: json['createdBy'] ?? '',
      clickCount: (json['clickCount'] ?? 0).toInt(),
      lastClickedAt: timestampToDate(json['lastClickedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category.value,
      'shortDescription': shortDescription,
      'disclaimer': disclaimer,
      'url': url,
      'logoUrl': logoUrl,
      'regions': regions,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'sortOrder': sortOrder,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
      'createdBy': createdBy,
      'clickCount': clickCount,
      'lastClickedAt': dateToTimestamp(lastClickedAt),
    };
  }

  Affiliate copyWith({
    String? id,
    String? title,
    AffiliateCategory? category,
    String? shortDescription,
    String? disclaimer,
    String? url,
    String? logoUrl,
    List<String>? regions,
    bool? isActive,
    bool? isFeatured,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? clickCount,
    DateTime? lastClickedAt,
  }) {
    return Affiliate(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      shortDescription: shortDescription ?? this.shortDescription,
      disclaimer: disclaimer ?? this.disclaimer,
      url: url ?? this.url,
      logoUrl: logoUrl ?? this.logoUrl,
      regions: regions ?? this.regions,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      clickCount: clickCount ?? this.clickCount,
      lastClickedAt: lastClickedAt ?? this.lastClickedAt,
    );
  }
}
