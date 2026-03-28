import 'package:flutter/material.dart';

// This widget displays a blinking icon inside a circle, which can be used to draw attention to a specific action or notification.
class BlinkingIconCircle extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color blinkColor;
  final double iconSize;
  final Duration beatDuration;

  const BlinkingIconCircle({
    super.key,
    required this.icon,
    this.iconColor = Colors.white,
    this.blinkColor = Colors.red,
    this.iconSize = 24.0,
    this.beatDuration = const Duration(milliseconds: 800),
  });

  @override
  State<BlinkingIconCircle> createState() => _BlinkingIconCircleState();
}

class _BlinkingIconCircleState extends State<BlinkingIconCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.beatDuration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.iconSize + 10,
            height: widget.iconSize + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.blinkColor.withOpacity(0.5),
            ),
          ),
        ),
        Container(
          width: widget.iconSize + 6,
          height: widget.iconSize + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.blinkColor,
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: widget.iconSize,
          ),
        ),
      ],
    );
  }
}
