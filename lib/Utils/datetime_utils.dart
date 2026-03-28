import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Convert a UTC date string to local time and format it.
  ///
  /// [utcDateString]: The UTC datetime string (e.g., '2025-06-17T09:00:00Z').
  /// [format]: Desired output format (e.g., 'dd-MM-yyyy hh:mm a').
  ///
  /// Returns a formatted local time string or empty string if parsing fails.
  static String utcToLocal(String utcDateString, String format) {
    try {
      final utcDateTime = DateTime.parse(utcDateString).toUtc();
      final localDateTime = utcDateTime.toLocal();
      return DateFormat(format).format(localDateTime);
    } catch (e) {
      return '';
    }
  }
}
