import '../utils/firestore_helpers.dart';

class Broker {
  final String id;
  final String name;
  final String? logoUrl;
  final String affiliateUrl;
  final String description;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Broker({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.affiliateUrl,
    required this.description,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory Broker.fromJson(String id, Map<String, dynamic> json) {
    return Broker(
      id: id,
      name: json['name'] ?? '',
      logoUrl: json['logoUrl'],
      affiliateUrl: json['affiliateUrl'] ?? '',
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? true,
      sortOrder: (json['sortOrder'] ?? 0).toInt(),
      createdAt: timestampToDate(json['createdAt']),
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'affiliateUrl': affiliateUrl,
      'description': description,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
    };
  }

  Broker copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? affiliateUrl,
    String? description,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Broker(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      affiliateUrl: affiliateUrl ?? this.affiliateUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
