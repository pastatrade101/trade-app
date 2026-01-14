import '../utils/firestore_helpers.dart';

const List<String> testimonialStatuses = [
  'pending',
  'published',
  'unpublished',
];

class Testimonial {
  const Testimonial({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.proofImageUrl,
    this.proofImagePath,
    this.publishedAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final String title;
  final String message;
  final String status;
  final String? proofImageUrl;
  final String? proofImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  bool get isPublished => status == 'published';
  bool get isPending => status == 'pending';

  factory Testimonial.fromJson(String id, Map<String, dynamic> json) {
    return Testimonial(
      id: id,
      authorUid: json['authorUid'] ?? '',
      authorName: json['authorName'] ?? '',
      authorRole: json['authorRole'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'pending',
      proofImageUrl: json['proofImageUrl'],
      proofImagePath: json['proofImagePath'],
      createdAt: timestampToDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: timestampToDate(json['updatedAt']) ?? DateTime.now(),
      publishedAt: timestampToDate(json['publishedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'title': title,
      'message': message,
      'status': status,
      'proofImageUrl': proofImageUrl,
      'proofImagePath': proofImagePath,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
      'publishedAt': dateToTimestamp(publishedAt),
    };
  }
}
