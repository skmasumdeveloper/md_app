import 'dart:io';
import 'package:cu_app/Commons/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen WebView-based video player for screen recordings.
/// WebView handles WebM/VP8 natively via Chrome — instant playback, no codec issues.
class ScreenRecordingPlayer extends StatefulWidget {
  final String videoUrl;
  final String fileName;

  const ScreenRecordingPlayer({
    super.key,
    required this.videoUrl,
    this.fileName = 'Call Recording',
  });

  @override
  State<ScreenRecordingPlayer> createState() => _ScreenRecordingPlayerState();
}

class _ScreenRecordingPlayerState extends State<ScreenRecordingPlayer> {
  late final WebViewController _webController;
  bool _isDownloading = false;
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(_buildPlayerHtml(widget.videoUrl));
  }

  String _buildPlayerHtml(String url) {
    // Escape single quotes in URL
    final safeUrl = url.replaceAll("'", "\\'");
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%; height: 100%;
    background: #000;
    display: flex; align-items: center; justify-content: center;
    overflow: hidden;
  }
  video {
    width: 100%;
    max-height: 100%;
    object-fit: contain;
    background: #000;
  }
</style>
</head>
<body>
<video
  src="$safeUrl"
  controls
  autoplay
  playsinline
  controlslist="nodownload"
  preload="auto"
></video>
</body>
</html>
''';
  }

  Future<void> _showDownloadModal() async {
    if (_isDownloading) return;
    _isDownloading = true;
    _progressNotifier.value = 0;

    final navigator = Navigator.of(context);

    // Show modal with live progress via ValueListenableBuilder
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: _progressNotifier,
        builder: (_, progress, __) {
          final pct = (progress * 100).toInt();
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 4,
                        color: Colors.red.shade400,
                        backgroundColor: Colors.white12,
                      ),
                      Center(
                        child: progress > 0
                            ? Text(
                                '$pct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : const Icon(Icons.download_rounded,
                                color: Colors.white54, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Downloading Recording...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress > 0 ? '$pct% complete' : 'Starting download...',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _isDownloading = false;
                  },
                  child:
                      const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Start download
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = widget.videoUrl.contains('.webm') ? 'webm' : 'mp4';
      final filePath = '${dir.path}/screen_recording_$ts.$ext';

      await Dio().download(
        widget.videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progressNotifier.value = received / total;
          }
        },
      );

      _isDownloading = false;
      if (navigator.canPop()) navigator.pop();

      if (!mounted) return;

      // Save to gallery with fallbacks
      final result = await _saveToGallery(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: result.startsWith('Recording')
              ? Colors.green
              : Colors.orange.shade800,
        ),
      );
    } catch (e) {
      _isDownloading = false;
      if (navigator.canPop()) navigator.pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  /// Save video file to device gallery with multiple fallbacks.
  /// Returns a message describing what happened.
  Future<String> _saveToGallery(String filePath) async {
    // Strategy 1: Try Gal.putVideo (works for .mp4/.mov on all platforms)
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(filePath, album: 'CU App');
      return 'Recording saved to gallery';
    } catch (e) {
      // Gal failed — likely unsupported format (.webm on iOS)
      debugPrint('[ScreenRecPlayer] Gal.putVideo failed: $e');
    }

    // Strategy 2: Android — copy to Movies folder directly
    if (Platform.isAndroid) {
      try {
        final moviesDir = Directory('/storage/emulated/0/Movies/CU App');
        if (!await moviesDir.exists()) {
          await moviesDir.create(recursive: true);
        }
        final fileName = filePath.split('/').last;
        await File(filePath).copy('${moviesDir.path}/$fileName');
        return 'Recording saved to Movies/CU App';
      } catch (_) {
        debugPrint('[ScreenRecPlayer] Android Movies folder save failed');
      }
    }

    // Strategy 3: Share sheet as last resort
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)]),
      );
      return 'Recording ready to share/save';
    } catch (_) {
      return 'Recording downloaded but could not save to gallery';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Call Recording',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            if (widget.fileName.isNotEmpty)
              Text(widget.fileName,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showDownloadModal,
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download',
          ),
        ],
      ),
      body: WebViewWidget(controller: _webController),
    );
  }
}

/// Inline chat bubble widget for screen recording messages.
class ScreenRecordingChatBubble extends StatelessWidget {
  final String message;
  final String fileName;
  final Color textColor;
  final Color secondaryTextColor;

  const ScreenRecordingChatBubble({
    super.key,
    required this.message,
    required this.fileName,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = message == 'expired';
    final isProcessing =
        message == 'processing' || message.isEmpty || message == 'null';

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red.shade900.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.red.shade900.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record,
                    color: Colors.red.shade400, size: 8),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Call Recording',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // if (!isExpired && !isProcessing)
                //   GestureDetector(
                //     onTap: () => _openPlayer(context),
                //     child: Icon(Icons.download_rounded,
                //         color: secondaryTextColor, size: 16),
                //   ),
              ],
            ),
          ),

          if (isProcessing)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recording is being processed...',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isExpired)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.timer_off, color: secondaryTextColor, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This recording has expired.',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => _openPlayer(context),
              child: Container(
                height: 140,
                color: const Color(0xFF111111),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade600,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),

          if (fileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                fileName,
                style: TextStyle(color: AppColors.black, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  static const _supportedFormats = {'.mp4', '.webm', '.mov', '.m4v', '.avi'};

  void _openPlayer(BuildContext context) {
    // Extract extension from URL (strip query params)
    final uri = Uri.tryParse(message);
    final path = uri?.path ?? message;
    final dotIndex = path.lastIndexOf('.');
    final ext = dotIndex != -1 ? path.substring(dotIndex).toLowerCase() : '';

    if (ext.isNotEmpty && !_supportedFormats.contains(ext)) {
      // Unsupported format — show popup
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.slow_motion_video_sharp,
              color: Colors.orange, size: 36),
          title: const Text('Unsupported Format'),
          content: Text(
            "$ext format is not supported for playback or download.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenRecordingPlayer(
          videoUrl: message,
          fileName: fileName,
        ),
      ),
    );
  }
}
