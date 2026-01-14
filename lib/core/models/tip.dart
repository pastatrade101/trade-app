import '../utils/firestore_helpers.dart';

const List<String> tipTypes = [
  'Market Insight',
  'Psychology',
  'Risk Management',
  'Common Mistake',
  'Session Tip',
];

const List<String> tipTagOptions = [
  'XAUUSD',
  'Forex',
  'Crypto',
  'Indices',
  'London',
  'New York',
  'Asia',
];

const List<String> tipStatuses = ['draft', 'published', 'archived'];

class TraderTip {
  final String id;
  final String title;
  final String type;
  final String content;
  final String action;
  final List<String> tags;
  final String? imageUrl;
  final String? imagePath;
  final String status;
  final String createdBy;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFeatured;
  final int likesCount;
  final int savesCount;

  const TraderTip({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.action,
    required this.tags,
    required this.imageUrl,
    required this.imagePath,
    required this.status,
    required this.createdBy,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    required this.isFeatured,
    required this.likesCount,
    required this.savesCount,
  });

  bool get isPublished => status == 'published';

  factory TraderTip.fromJson(String id, Map<String, dynamic> json) {
    final legacyCategory = json['category'] as String?;
    final legacyType = json['type'] as String?;
    final resolvedType = _normalizeTipType(legacyType) ??
        _legacyTypeFromCategory(legacyCategory) ??
        tipTypes.first;
    final resolvedContent = _resolveContent(json);
    final resolvedAction = _resolveAction(json);
    final resolvedTags = List<String>.from(
      json['tags'] ??
          json['markets'] ??
          json['tagsOrMarkets'] ??
          const <String>[],
    );
    return TraderTip(
      id: id,
      title: json['title'] ?? '',
      type: resolvedType,
      content: resolvedContent,
      action: resolvedAction,
      tags: resolvedTags,
      imageUrl: json['imageUrl'],
      imagePath: json['imagePath'],
      status: json['status'] ?? 'draft',
      createdBy: json['createdBy'] ?? '',
      authorName: json['authorName'] ?? '',
      createdAt: timestampToDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: timestampToDate(json['updatedAt']) ?? DateTime.now(),
      isFeatured: json['isFeatured'] ?? false,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      savesCount: (json['savesCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'content': content,
      'action': action,
      'tags': tags,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'status': status,
      'createdBy': createdBy,
      'authorName': authorName,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
      'isFeatured': isFeatured,
      'likesCount': likesCount,
      'savesCount': savesCount,
    };
  }

  TraderTip copyWith({
    String? id,
    String? title,
    String? type,
    String? content,
    String? action,
    List<String>? tags,
    String? imageUrl,
    String? imagePath,
    String? status,
    String? createdBy,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFeatured,
    int? likesCount,
    int? savesCount,
  }) {
    return TraderTip(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      action: action ?? this.action,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFeatured: isFeatured ?? this.isFeatured,
      likesCount: likesCount ?? this.likesCount,
      savesCount: savesCount ?? this.savesCount,
    );
  }
}

String? _normalizeTipType(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return tipTypes.contains(value) ? value : null;
}

String? _legacyTypeFromCategory(String? category) {
  if (category == null || category.isEmpty) {
    return null;
  }
  switch (category) {
    case 'Risk Management':
      return 'Risk Management';
    case 'Psychology':
    case 'Pro Mindset':
      return 'Psychology';
    case 'Common Mistakes':
      return 'Common Mistake';
    case 'Session Behavior':
      return 'Session Tip';
    default:
      return 'Market Insight';
  }
}

String _resolveContent(Map<String, dynamic> json) {
  final content = json['content'] as String?;
  if (content != null && content.trim().isNotEmpty) {
    return content;
  }
  final keyInsight = json['keyInsight'] as String?;
  final explanation = json['explanation'] as String?;
  if (keyInsight != null && explanation != null && explanation.trim().isNotEmpty) {
    return '$keyInsight\n\n$explanation';
  }
  return keyInsight ?? explanation ?? '';
}

String _resolveAction(Map<String, dynamic> json) {
  final action = json['action'] as String?;
  if (action != null && action.trim().isNotEmpty) {
    return action;
  }
  final actionable = json['actionable'];
  if (actionable is List && actionable.isNotEmpty) {
    final value = actionable.first?.toString() ?? '';
    return value;
  }
  return '';
}
