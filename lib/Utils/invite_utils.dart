import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../Commons/app_strings.dart';

class InviteUtils {
  /// Build formatted date line like: "Date: 22nd January,2026 at 06:30 PM".
  static String _formatDateLine(String? meetingStartTime) {
    if (meetingStartTime == null || meetingStartTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(meetingStartTime).toLocal();
      final day = dt.day;
      String suffix = 'th';
      if (!(day >= 11 && day <= 13)) {
        final last = day % 10;
        if (last == 1) suffix = 'st';
        if (last == 2) suffix = 'nd';
        if (last == 3) suffix = 'rd';
      }
      final month = DateFormat('MMMM').format(dt);
      final year = dt.year;
      final time = DateFormat('hh:mm a').format(dt);
      return 'Date: ${day}${suffix} ${month},${year} at $time';
    } catch (_) {
      return '';
    }
  }

  /// Build the invite message text used for copying and sharing.
  static String buildInviteMessage({
    required String link,
    String? pin,
    String? meetingStartTime,
  }) {
    final dateLine = _formatDateLine(meetingStartTime);
    return 'Join Meeting on ${AppStrings.appName} :\n${dateLine.isNotEmpty ? dateLine + '\n' : ''}Link: $link\nPin: ${pin ?? ''}';
  }

  /// Copies the invite message to clipboard and shows a snackbar confirmation.
  static Future<void> copyInviteToClipboard(
      {required BuildContext context,
      required String link,
      String? pin,
      String? meetingStartTime,
      String successMessage = 'Invite copied'}) async {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No meeting link available')));
      return;
    }
    final msg = buildInviteMessage(
        link: link, pin: pin, meetingStartTime: meetingStartTime);
    await Clipboard.setData(ClipboardData(text: msg));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  /// Share the invite using the platform share sheet.
  static Future<void> shareInvite(
      {required String link, String? pin, String? meetingStartTime}) async {
    if (link.isEmpty) return;
    final msg = buildInviteMessage(
        link: link, pin: pin, meetingStartTime: meetingStartTime);
    await Share.share(msg);
  }
}
