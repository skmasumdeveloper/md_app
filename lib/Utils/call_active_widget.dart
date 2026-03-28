import 'package:flutter/material.dart';

import 'package:cu_app/Commons/app_theme_colors.dart';

// This widget displays an active call status with options to return to the call or end it.
class CallActiveWidget extends StatelessWidget {
  final String userName;
  final bool isVideoCall;
  final VoidCallback onTapToReturn;
  final VoidCallback onEndCall;

  const CallActiveWidget({
    Key? key,
    required this.userName,
    required this.isVideoCall,
    required this.onTapToReturn,
    required this.onEndCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.onlineStatus,
      child: InkWell(
        onTap: onTapToReturn,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                isVideoCall ? Icons.videocam : Icons.call,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$userName - ${isVideoCall ? "Video" : "Audio"} Call',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.white),
                onPressed: onEndCall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
