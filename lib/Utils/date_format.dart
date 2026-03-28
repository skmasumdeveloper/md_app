import 'package:intl/intl.dart';

// This file contains utility functions and extensions for the application, including date formatting, string validation, and custom text input formatting.
String dateFromatter({String? dateTimeAsString, required String dateFormat}) {
  String format =
      DateFormat(dateFormat).format(DateTime.parse(dateTimeAsString ?? ""));
  return format;
}
