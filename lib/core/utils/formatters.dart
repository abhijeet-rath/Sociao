import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static final _grouped = NumberFormat('#,###');

  /// 1450 -> "1,450" (post action pills).
  static String count(int value) => _grouped.format(value);

  /// 490 -> "490", 12800 -> "12,8k", 1200000 -> "1,2M" (profile stats).
  static String compact(int value) {
    if (value < 1000) return value.toString();
    final (divisor, suffix) = value >= 1000000 ? (1000000, 'M') : (1000, 'k');
    var text = (value / divisor).toStringAsFixed(1);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return '${text.replaceAll('.', ',')}$suffix';
  }

  /// "2m ago" for posts and comments.
  static String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  /// "3 min ago" for inbox and chat.
  static String messageTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return DateFormat('MMM d').format(time);
  }
}
