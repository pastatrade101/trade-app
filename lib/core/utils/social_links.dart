String? validateSocialUrl(String platform, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      uri.host.isEmpty ||
      !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return 'Use a full URL for ${platformLabel(platform)}.';
  }
  final host = uri.host.toLowerCase();
  final allowed = _socialDomains[platform] ?? const <String>[];
  final matches = allowed.any(
    (domain) => host == domain || host.endsWith('.$domain'),
  );
  if (!matches) {
    return 'Only ${platformLabel(platform)} links are allowed.';
  }
  return null;
}

String platformLabel(String platform) {
  switch (platform) {
    case 'twitter':
      return 'X (Twitter)';
    case 'telegram':
      return 'Telegram';
    case 'instagram':
      return 'Instagram';
    case 'youtube':
      return 'YouTube';
    default:
      return 'this platform';
  }
}

Map<String, String> sanitizeSocialLinks(Map<String, String> raw) {
  final cleaned = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      cleaned[entry.key] = value;
    }
  }
  return cleaned;
}

const Map<String, List<String>> _socialDomains = {
  'twitter': ['x.com', 'twitter.com'],
  'telegram': ['t.me'],
  'instagram': ['instagram.com'],
  'youtube': ['youtube.com', 'youtu.be'],
};
