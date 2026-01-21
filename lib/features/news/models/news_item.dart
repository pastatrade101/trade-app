class NewsItem {
  NewsItem({
    required this.id,
    required this.title,
    required this.link,
    required this.description,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String link;
  final String description;
  final DateTime publishedAt;

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final publishedRaw = json['publishedAt']?.toString();
    final publishedAt = publishedRaw != null
        ? DateTime.tryParse(publishedRaw)
        : null;
    return NewsItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      publishedAt:
          publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
