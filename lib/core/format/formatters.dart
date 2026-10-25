import 'package:intl/intl.dart';

/// Format sesuai PRD: poin pakai pemisah ribuan titik, berat dalam kg
/// dengan koma desimal, waktu dalam WIB (UTC+7).
class Fmt {
  static final _points = NumberFormat.decimalPattern('id_ID');
  static final _kg = NumberFormat('#,##0.00', 'id_ID');

  static String points(int value) => _points.format(value);

  static String signedPoints(int value) => '${value >= 0 ? '+' : '−'}${points(value.abs())}';

  /// Berat dari gram (API) ke kg, 2 desimal.
  static String kg(int grams) => _kg.format(grams / 1000);

  static DateTime toWib(DateTime t) => t.toUtc().add(const Duration(hours: 7));

  static String time(DateTime t) => '${DateFormat('HH:mm', 'id_ID').format(toWib(t))} WIB';

  static String timeWithSeconds(DateTime t) => '${DateFormat('HH:mm:ss', 'id_ID').format(toWib(t))} WIB';

  static String date(DateTime t) => DateFormat('d MMM yyyy', 'id_ID').format(toWib(t));

  /// Tanggal kalender dari date picker (tanpa konversi zona waktu).
  static String calendarDate(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

  static String dateTime(DateTime t) => '${date(t)}, ${time(t)}';

  static String monthYear(DateTime t) => DateFormat('MMMM yyyy', 'id_ID').format(toWib(t));

  static String shortMonthYear(DateTime t) => DateFormat('MMM yyyy', 'id_ID').format(toWib(t));

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Hari Ini, 24 Okt 2026", "Kemarin, 23 Okt 2026", atau "20 Okt 2026".
  static String dayHeader(DateTime t, DateTime now) {
    final d = toWib(t), n = toWib(now);
    if (_sameDay(d, n)) return 'Hari Ini, ${date(t)}';
    if (_sameDay(d, n.subtract(const Duration(days: 1)))) return 'Kemarin, ${date(t)}';
    return date(t);
  }

  /// "10:15 WIB" untuk hari ini, "Kemarin", atau "22 Okt 2026".
  static String relativeShort(DateTime t, DateTime now) {
    final d = toWib(t), n = toWib(now);
    if (_sameDay(d, n)) return time(t);
    if (_sameDay(d, n.subtract(const Duration(days: 1)))) return 'Kemarin';
    return date(t);
  }

  static String ago(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
