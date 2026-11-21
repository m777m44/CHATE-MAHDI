import 'package:timeago/timeago.dart' as timeago;

String timeAgo(dynamic iso) {
  try {
    final dt = DateTime.parse(iso.toString());
    return timeago.format(dt, locale: 'ar');
  } catch (_) {
    return '';
  }
}

void initTimeago() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
}

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Absolute URL for media returned either as absolute (cloudinary) or as a
/// server-relative /uploads/... path (local storage driver).
String mediaUrl(String raw, String apiBaseUrl) {
  final base = apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
  if (raw.startsWith('http')) return raw;
  return '$base$raw';
}
