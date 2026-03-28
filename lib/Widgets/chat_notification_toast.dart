import 'package:flutter/material.dart';

import '../Commons/app_theme_colors.dart';

class ChatNotificationToast {
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context, {
    required String senderName,
    required String message,
    required VoidCallback onTap,
  }) {
    if (_overlayEntry != null) return;

    final colors = context.appColors;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: 40,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              onTap();
              hide();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.toastBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/icons/app-logo.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.toastSubtext,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.toastText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 5), () {
      hide();
    });
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
