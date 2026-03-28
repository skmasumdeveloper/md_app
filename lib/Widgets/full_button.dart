import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';
import '../Commons/app_sizes.dart';

// This widget provides a full-width button with customizable label, background color, and animation effects on tap.
class FullButton extends StatefulWidget {
  final String label;
  final Function() onPressed;
  final Color? backgroundColor;
  final Color? titleColor;
  final double? width;
  final Duration? duration;
  final bool? isGradientOrange;

  const FullButton(
      {super.key,
      this.isGradientOrange = false,
      required this.label,
      required this.onPressed,
      this.backgroundColor,
      this.titleColor,
      this.width,
      this.duration});

  @override
  State<FullButton> createState() => _FullButtonState();
}

class _FullButtonState extends State<FullButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  double? _scale;

  @override
  void initState() {
    _animationController = AnimationController(
        vsync: this,
        duration: widget.duration ?? const Duration(milliseconds: 150),
        lowerBound: 0.0,
        upperBound: 0.06)
      ..addListener(() {
        setState(() {});
      });
    super.initState();
  }

  @override
  void dispose() {
    _animationController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _animationController!.value;
    return GestureDetector(
      onTap: () {
        _animationController!.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          _animationController!.reverse();
          widget.onPressed.call();
        });
      },
      child: Transform.scale(
        scale: _scale,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: AppSizes.largeButtonHeight,
          decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    offset: const Offset(8, 8),
                    blurRadius: 15,
                    color: widget.isGradientOrange == true
                        ? Colors.transparent
                        : AppColors.primary.withOpacity(0.4))
              ],
              gradient: widget.isGradientOrange == true
                  ? AppColors.themeGradient
                  : AppColors.buttonGradientColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.cardCornerRadius * 4),
                topRight: Radius.circular(AppSizes.cardCornerRadius * 4),
                bottomLeft: Radius.circular(AppSizes.cardCornerRadius * 4),
                bottomRight: Radius.circular(AppSizes.cardCornerRadius * 4),
              )),
          child: Center(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: AppColors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
