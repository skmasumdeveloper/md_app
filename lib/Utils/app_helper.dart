// ignore_for_file: camel_case_extensions, unnecessary_null_comparison

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// This file contains utility functions and extensions for the application, including date formatting, string validation, and custom text input formatting.
class AppHelper {
  static String getDateFromString(String givenDate) {
    var inputDate = DateTime.parse(givenDate);
    var outputFormat = DateFormat('hh:mm a');
    var outputDate = outputFormat.format(inputDate);
    return outputDate;
  }

  static void openKeyboard(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  static String getStringDateFromTimestamp(int timestamp) {
    DateTime inputDate =
        DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: false);
    var outputFormat = DateFormat('dd MMM, yyyy').format(inputDate);
    return outputFormat;
  }

  static String getStringTimeFromTimestamp(int timestamp) {
    DateTime inputDate =
        DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: false);
    var outputFormat = DateFormat('hh:mm a').format(inputDate);
    return outputFormat;
  }
}

extension extString on String {
  bool get isValidEmail {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(this);
  }

  bool get isValidName {
    final nameRegExp =
        RegExp(r"^\s*([A-Za-z]{1,}([\.,] |[-']| ))+[A-Za-z]+\.?\s*$");
    return nameRegExp.hasMatch(this);
  }

  bool get isValidPassword {
    final passwordRegExp = RegExp(
        r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\><*~]).{8,}/pre>');
    return passwordRegExp.hasMatch(this);
  }

  bool get isNotNull {
    return this != null;
  }

  bool get isValidPhone {
    final phoneRegExp = RegExp(r"^\+?0[0-9]{10}$");
    return phoneRegExp.hasMatch(this);
  }
}

extension DateHelper on DateTime {
  String formatDate() {
    final formatter = DateFormat('dd MMM, yyyy');
    return formatter.format(this);
  }

  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  int getDifferenceInDaysWithNow() {
    final now = DateTime.now();
    return now.difference(this).inDays;
  }
}

extension ListExtensions<T> on List<T> {
  Iterable<T> whereWithIndex(bool Function(T element, int index) test) {
    final List<T> result = [];
    for (var i = 0; i < length; i++) {
      if (test(this[i], i)) {
        result.add(this[i]);
      }
    }
    return result;
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: capitalize(newValue.text),
      selection: newValue.selection,
    );
  }
}

String capitalize(String value) {
  if (value.trim().isEmpty) return "";
  return "${value[0].toUpperCase()}${value.substring(1).toLowerCase()}";
}
