import 'package:intl/intl.dart';

class Fmt {
  const Fmt._();

  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _time24 = DateFormat('HH:mm');
  static final DateFormat _date = DateFormat('EEE, d MMM');
  static final DateFormat _dateLong = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _dateShort = DateFormat('d MMM yyyy');
  static final DateFormat _stamp = DateFormat('d MMM · h:mm a');

  static String time(DateTime? value) => value == null ? '—' : _time.format(value.toLocal());
  static String time24(DateTime? value) => value == null ? '—' : _time24.format(value.toLocal());
  static String date(DateTime? value) => value == null ? '—' : _date.format(value.toLocal());
  static String dateLong(DateTime? value) => value == null ? '—' : _dateLong.format(value.toLocal());
  static String dateShort(DateTime? value) => value == null ? '—' : _dateShort.format(value.toLocal());
  static String stamp(DateTime? value) => value == null ? '—' : _stamp.format(value.toLocal());

  /// "Today", "Yesterday" or "Mon, 3 Nov".
  static String dayLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _date.format(value);
  }

  static String duration(Duration d) {
    final total = d.inSeconds.abs().clamp(0, 86400 * 2);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return total > 0 ? '${total}s' : '0m';
  }

  static String durationCompact(Duration d) {
    final total = d.inSeconds.abs().clamp(0, 86400 * 2);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return total > 0 ? '${total}s' : '0m';
  }

  /// 02:14:32
  static String clock(Duration d) {
    final total = d.inSeconds.abs();
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 02:14
  static String clockShort(Duration d) {
    final total = d.inSeconds.abs();
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }

  static String relative(DateTime? value) {
    if (value == null) return 'never';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 15) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static String dayKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, "0")}-${value.day.toString().padLeft(2, "0")}';

  static DateTime startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);
  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}
