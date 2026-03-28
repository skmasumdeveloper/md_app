import 'dart:math';
import 'package:flutter/material.dart';

import '../Commons/app_colors.dart';

enum LoaderAnimationStyle {
  spinner,
  bouncingDots,
  fadingBars,
  scalingPulse,
  rotatingDots,
  waveLoader,
  rotatingCircle,
  jumpingBalls,
  circularProgressDots,
  flipLoader,
  pulseRing,
  stretchBars,
  loadingGrid,
  chasingDots,
  foldingCube,
  ripple,
  spinningLines,
  dualRing,
  hourGlass,
  cubeGrid,
  circlePulse,
  orbit,
  newtonCradle,
  audioWave,
  circleWobble,
  threeDotsFade,
  circleFlip,
  squareSpin,
  clockLoader,
  atom,
}

class AnimatedLoader extends StatefulWidget {
  final LoaderAnimationStyle animationStyle;
  final double size;
  final Color color;
  final Color? secondaryColor;
  final int itemCount;

  const AnimatedLoader({
    super.key,
    this.animationStyle = LoaderAnimationStyle.spinner,
    this.size = 50,
    this.color = Colors.blue,
    this.secondaryColor,
    this.itemCount = 3,
  });

  @override
  _AnimatedLoaderState createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

// 1. Spinner (default)
  Widget _buildSpinner() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _SpinnerPainter(color: widget.color),
        ),
      ),
    );
  }

  // 2. Bouncing Dots
  Widget _buildBouncingDots() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          final startDelayFraction = index * 0.2;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + startDelayFraction) % 1.0;
              double offset = 0;
              if (progress < 0.5) {
                offset = -10 * (progress / 0.5);
              } else {
                offset = -10 * ((1 - progress) / 0.5);
              }
              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: Dot(
              color: widget.color,
              size: widget.size / 6,
            ),
          );
        }),
      ),
    );
  }

  // 3. Fading Bars
  Widget _buildFadingBars() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          final startDelayFraction = index * 0.1;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + startDelayFraction) % 1.0;
              double opacity;
              if (progress < 0.5) {
                opacity = progress * 2;
              } else {
                opacity = (1 - progress) * 2;
              }
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: child,
              );
            },
            child: Container(
              width: widget.size / 12,
              height: widget.size / 2,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.size / 24),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 4. Scaling Pulse
  Widget _buildScalingPulse() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double scale = 0.5 + 0.5 * (_controller.value);
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: widget.size / 2,
            height: widget.size / 2,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // 5. Rotating Dots
  Widget _buildRotatingDots() {
    final double radius = widget.size / 2.5;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * pi,
            child: child,
          );
        },
        child: Stack(
          children: List.generate(widget.itemCount, (index) {
            final angle = (2 * pi / widget.itemCount) * index;
            final double dotSize = widget.size / 8;
            return Positioned(
              left: widget.size / 2 + radius * cos(angle) - dotSize / 2,
              top: widget.size / 2 + radius * sin(angle) - dotSize / 2,
              child: Dot(
                color: widget.color,
                size: dotSize,
              ),
            );
          }),
        ),
      ),
    );
  }

  // 6. Wave Loader
  Widget _buildWaveLoader() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          final startDelayFraction = index * 0.2;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + startDelayFraction) % 1.0;
              double scaleY;
              if (progress < 0.5) {
                scaleY = 0.5 + progress;
              } else {
                scaleY = 0.5 + (1 - progress);
              }
              return Transform.scale(
                scaleY: scaleY,
                scaleX: 1,
                child: child,
              );
            },
            child: Container(
              width: widget.size / 12,
              height: widget.size / 2,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.size / 24),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 7. Rotating Circle
  Widget _buildRotatingCircle() {
    final double radius = widget.size / 3;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: List.generate(widget.itemCount, (index) {
              final double angle = (2 * pi / widget.itemCount) * index +
                  (_controller.value * 2 * pi);
              final double scale = 0.5 +
                  0.5 * (sin(_controller.value * 2 * pi * 3 + index) + 1) / 2;
              final double dotSize = widget.size / 6 * scale;
              final Offset offset = Offset(
                widget.size / 2 + radius * cos(angle) - dotSize / 2,
                widget.size / 2 + radius * sin(angle) - dotSize / 2,
              );
              return Positioned(
                left: offset.dx,
                top: offset.dy,
                child: Dot(
                  color: widget.color,
                  size: dotSize,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // 8. Jumping Balls
  Widget _buildJumpingBalls() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          final startDelayFraction = index * 0.25;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + startDelayFraction) % 1.0;
              double offset = 0;
              if (progress < 0.5) {
                offset = -20 * (progress / 0.5);
              } else {
                offset = -20 * ((1 - progress) / 0.5);
              }
              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: Dot(
              color: widget.color,
              size: widget.size / 7,
            ),
          );
        }),
      ),
    );
  }

  // 9. Circular Progress Dots
  Widget _buildCircularProgressDots() {
    final double radius = widget.size / 2.5;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: List.generate(widget.itemCount, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress =
                  (_controller.value + index / widget.itemCount) % 1.0;
              final scale = 0.3 +
                  0.7 * (progress < 0.5 ? (progress * 2) : (2 - progress * 2));
              final angle = 2 * pi * index / widget.itemCount;
              final double dotSize = widget.size / 8 * scale;
              return Positioned(
                left: widget.size / 2 + radius * cos(angle) - dotSize / 2,
                top: widget.size / 2 + radius * sin(angle) - dotSize / 2,
                child: Dot(
                  color: widget.color.withOpacity(scale.clamp(0.3, 1.0)),
                  size: dotSize,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // 10. Flip Loader
  Widget _buildFlipLoader() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          final angle = value * 2 * pi;
          final isHalf = value > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.02)
              ..rotateY(angle),
            child: Container(
              width: widget.size / 2,
              height: widget.size / 2,
              decoration: BoxDecoration(
                color: isHalf ? widget.color.withOpacity(0.5) : widget.color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  // 11. Pulse Ring
  Widget _buildPulseRing() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          final delay = index * 0.3;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double scale = 0.5 + 0.5 * progress;
              double opacity = (1.0 - progress).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // 12. Stretch Bars
  Widget _buildStretchBars() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          final delay = index * 0.15;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double heightFactor =
                  progress < 0.5 ? (progress * 2) : (2 - progress * 2);
              return Container(
                width: widget.size / 12,
                height: widget.size / 2 * heightFactor,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.size / 24),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // 13. Loading Grid
  Widget _buildLoadingGrid() {
    const int rowCount = 3;
    const int colCount = 3;
    const int total = rowCount * colCount;
    final double spacing = widget.size / 15;
    final double dotSize = (widget.size - spacing * (colCount - 1)) / colCount;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
        ),
        itemCount: total,
        itemBuilder: (context, index) {
          final delay = (index / total) * 1.0;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double scale = 0.3 +
                  0.7 * (progress < 0.5 ? progress * 2 : (2 - progress * 2));
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Dot(
              color: widget.color,
              size: dotSize,
            ),
          );
        },
      ),
    );
  }

  // 14. Chasing Dots
  Widget _buildChasingDots() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 2 * pi,
                  child: child,
                );
              },
              child: Center(
                child: Dot(
                  color: widget.color.withOpacity(0.6),
                  size: widget.size / 3,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    cos(_controller.value * 2 * pi) * widget.size / 4,
                    sin(_controller.value * 2 * pi) * widget.size / 4,
                  ),
                  child: Transform.rotate(
                    angle: _controller.value * 2 * pi,
                    child: child,
                  ),
                );
              },
              child: Center(
                child: Dot(
                  color: widget.color,
                  size: widget.size / 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 15. Folding Cube
  Widget _buildFoldingCube() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: List.generate(4, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + index * 0.25) % 1.0;
              double rotation = progress < 0.5 ? progress * pi : pi;
              double scale = progress < 0.5 ? 1.0 : 1.0 - (progress - 0.5) * 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateY(index % 2 == 0 ? rotation : 0)
                  ..rotateX(index % 2 == 1 ? rotation : 0)
                  ..scale(scale, scale, 1.0),
                child: child,
              );
            },
            child: Container(
              width: widget.size / 2,
              height: widget.size / 2,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.7),
                border: Border.all(color: widget.color, width: 2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 16. Ripple
  Widget _buildRipple() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          final delay = index * 0.3;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double scale = progress;
              double opacity = 1.0 - progress;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withOpacity(opacity),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // 17. Spinning Lines
  Widget _buildSpinningLines() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _SpinningLinesPainter(
          color: widget.color,
          controller: _controller,
          lineCount: 12,
        ),
      ),
    );
  }

  // 18. Dual Ring
  Widget _buildDualRing() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: CustomPaint(
              painter: _RingPainter(
                color: widget.color.withOpacity(0.3),
                strokeWidth: widget.size / 10,
              ),
              size: Size(widget.size, widget.size),
            ),
          ),
          RotationTransition(
            turns: ReverseAnimation(_controller),
            child: CustomPaint(
              painter: _RingPainter(
                color: widget.color,
                strokeWidth: widget.size / 10,
              ),
              size: Size(widget.size, widget.size),
            ),
          ),
        ],
      ),
    );
  }

  // 19. Hour Glass
  Widget _buildHourGlass() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double topHeight = progress < 0.5 ? 1.0 - progress * 2 : 0.0;
          double bottomHeight = progress > 0.5 ? (progress - 0.5) * 2 : 0.0;
          return Stack(
            children: [
              // Top part
              Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: _TriangleClipper(direction: AxisDirection.down),
                  child: Container(
                    width: widget.size * 0.6,
                    height: widget.size * 0.5 * topHeight,
                    color: widget.color,
                  ),
                ),
              ),
              // Bottom part
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipPath(
                  clipper: _TriangleClipper(direction: AxisDirection.up),
                  child: Container(
                    width: widget.size * 0.6,
                    height: widget.size * 0.5 * bottomHeight,
                    color: widget.color,
                  ),
                ),
              ),
              // Middle dot
              Center(
                child: Dot(
                  color: widget.color,
                  size: widget.size / 10,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 20. Cube Grid
  Widget _buildCubeGrid() {
    const int count = 9;
    final double spacing = widget.size / 15;
    // final double cubeSize = (widget.size - spacing * 2) / 3;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        children: List.generate(count, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.1;
              double progress = (_controller.value + delay) % 1.0;
              double scale = 0.3 +
                  0.7 * (progress < 0.5 ? progress * 2 : (2 - progress * 2));
              return Transform.scale(
                scale: scale,
                child: Transform.rotate(
                  angle: progress * pi / 2,
                  child: child,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 21. Circle Pulse
  Widget _buildCirclePulse() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double scale = 0.5 + 0.5 * sin(progress * pi);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }

  // 22. Orbit
  Widget _buildOrbit() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          Center(
            child: Dot(
              color: widget.color,
              size: widget.size / 4,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  cos(_controller.value * 2 * pi) * widget.size / 3,
                  sin(_controller.value * 2 * pi) * widget.size / 3,
                ),
                child: child,
              );
            },
            child: Dot(
              color: widget.secondaryColor ?? widget.color.withOpacity(0.7),
              size: widget.size / 6,
            ),
          ),
        ],
      ),
    );
  }

  // 23. Newton's Cradle
  Widget _buildNewtonCradle() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Stack(
        children: [
          // String
          Positioned(
            top: 0,
            left: widget.size / 2 - 1,
            child: Container(
              width: 2,
              height: widget.size / 2,
              color: Colors.grey[300],
            ),
          ),
          // Balls
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double swing = sin(_controller.value * pi) * 0.4;
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-widget.size / 4, 0),
                    child: Transform.rotate(
                      angle: swing,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(widget.size / 4, 0),
                    child: Transform.rotate(
                      angle: -swing,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: widget.size / 3,
                  color: Colors.grey[300],
                ),
                Dot(
                  color: widget.color,
                  size: widget.size / 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 24. Audio Wave
  Widget _buildAudioWave() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          final delay = index * 0.15;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double height =
                  widget.size / 2 * (0.2 + 0.8 * sin(progress * pi));
              return Container(
                width: widget.size / 12,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.size / 24),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // 25. Circle Wobble
  Widget _buildCircleWobble() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double scaleX = 1.0 + 0.2 * sin(progress * 2 * pi);
          double scaleY = 1.0 - 0.2 * sin(progress * 2 * pi);
          return Transform.scale(
            scaleX: scaleX,
            scaleY: scaleY,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }

  // 26. Three Dots Fade
  Widget _buildThreeDotsFade() {
    return SizedBox(
      width: widget.size,
      height: widget.size / 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          final delay = index * 0.15;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double progress = (_controller.value + delay) % 1.0;
              double opacity = sin(progress * pi);
              return Opacity(
                opacity: opacity,
                child: child,
              );
            },
            child: Dot(
              color: widget.color,
              size: widget.size / 6,
            ),
          );
        }),
      ),
    );
  }

  // 27. Circle Flip
  Widget _buildCircleFlip() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double flip = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(flip * pi),
            alignment: Alignment.center,
            child: Container(
              width: widget.size / 2,
              height: widget.size / 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          );
        },
      ),
    );
  }

  // 28. Square Spin
  Widget _buildSquareSpin() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double rotation = progress * 2 * pi;
          double scale = 0.5 + 0.5 * sin(progress * pi);
          return Transform(
            transform: Matrix4.identity()
              ..rotateZ(rotation)
              ..scale(scale, scale),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Container(
          width: widget.size / 2,
          height: widget.size / 2,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.send,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  // 29. Clock Loader
  Widget _buildClockLoader() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Clock face
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 2),
            ),
          ),
          // Hour hand
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double hourAngle = _controller.value * pi / 6;
              return Transform.rotate(
                angle: hourAngle,
                child: child,
              );
            },
            child: Center(
              child: Container(
                width: 2,
                height: widget.size / 3,
                margin: EdgeInsets.only(bottom: widget.size / 6),
                color: widget.color,
              ),
            ),
          ),
          // Minute hand
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double minuteAngle = _controller.value * 2 * pi;
              return Transform.rotate(
                angle: minuteAngle,
                child: child,
              );
            },
            child: Center(
              child: Container(
                width: 2,
                height: widget.size / 2.5,
                margin: EdgeInsets.only(bottom: widget.size / 5),
                color: widget.color,
              ),
            ),
          ),
          // Center dot
          Center(
            child: Dot(
              color: widget.color,
              size: widget.size / 15,
            ),
          ),
        ],
      ),
    );
  }

  // 30. Atom
  Widget _buildAtom() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double rotation = _controller.value * 2 * pi;
          return Stack(
            children: [
              // Orbit rings
              Transform.rotate(
                angle: rotation,
                child: CustomPaint(
                  painter: _OrbitPainter(
                    color: widget.color.withOpacity(0.3),
                    orbitCount: 3,
                  ),
                  size: Size(widget.size, widget.size),
                ),
              ),
              // Center nucleus
              Center(
                child: Dot(
                  color: widget.color,
                  size: widget.size / 5,
                ),
              ),
              // Electrons
              for (int i = 0; i < 3; i++)
                Positioned(
                  left: widget.size / 2 +
                      cos(rotation + i * 2 * pi / 3) * widget.size / 3 -
                      widget.size / 12,
                  top: widget.size / 2 +
                      sin(rotation + i * 2 * pi / 3) * widget.size / 3 -
                      widget.size / 12,
                  child: Dot(
                    color: widget.secondaryColor ?? Colors.blue,
                    size: widget.size / 6,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.animationStyle) {
      case LoaderAnimationStyle.spinner:
        return _buildSpinner();
      case LoaderAnimationStyle.bouncingDots:
        return _buildBouncingDots();
      case LoaderAnimationStyle.fadingBars:
        return _buildFadingBars();
      case LoaderAnimationStyle.scalingPulse:
        return _buildScalingPulse();
      case LoaderAnimationStyle.rotatingDots:
        return _buildRotatingDots();
      case LoaderAnimationStyle.waveLoader:
        return _buildWaveLoader();
      case LoaderAnimationStyle.rotatingCircle:
        return _buildRotatingCircle();
      case LoaderAnimationStyle.jumpingBalls:
        return _buildJumpingBalls();
      case LoaderAnimationStyle.circularProgressDots:
        return _buildCircularProgressDots();
      case LoaderAnimationStyle.flipLoader:
        return _buildFlipLoader();
      case LoaderAnimationStyle.pulseRing:
        return _buildPulseRing();
      case LoaderAnimationStyle.stretchBars:
        return _buildStretchBars();
      case LoaderAnimationStyle.loadingGrid:
        return _buildLoadingGrid();
      case LoaderAnimationStyle.chasingDots:
        return _buildChasingDots();
      case LoaderAnimationStyle.foldingCube:
        return _buildFoldingCube();
      case LoaderAnimationStyle.ripple:
        return _buildRipple();
      case LoaderAnimationStyle.spinningLines:
        return _buildSpinningLines();
      case LoaderAnimationStyle.dualRing:
        return _buildDualRing();
      case LoaderAnimationStyle.hourGlass:
        return _buildHourGlass();
      case LoaderAnimationStyle.cubeGrid:
        return _buildCubeGrid();
      case LoaderAnimationStyle.circlePulse:
        return _buildCirclePulse();
      case LoaderAnimationStyle.orbit:
        return _buildOrbit();
      case LoaderAnimationStyle.newtonCradle:
        return _buildNewtonCradle();
      case LoaderAnimationStyle.audioWave:
        return _buildAudioWave();
      case LoaderAnimationStyle.circleWobble:
        return _buildCircleWobble();
      case LoaderAnimationStyle.threeDotsFade:
        return _buildThreeDotsFade();
      case LoaderAnimationStyle.circleFlip:
        return _buildCircleFlip();
      case LoaderAnimationStyle.squareSpin:
        return _buildSquareSpin();
      case LoaderAnimationStyle.clockLoader:
        return _buildClockLoader();
      case LoaderAnimationStyle.atom:
        return _buildAtom();
      default:
        return _buildSpinner(); // Default loader
    }
  }
}

class Dot extends StatelessWidget {
  final double size;
  final Color color;

  const Dot({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final Color color;

  _SpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      3 * pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _OrbitPainter extends CustomPainter {
  final Color color;
  final int orbitCount;

  _OrbitPainter({required this.color, this.orbitCount = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    for (int i = 0; i < orbitCount; i++) {
      final angle = (2 * pi / orbitCount) * i;
      final offset = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.orbitCount != orbitCount;
  }
}

class _SpinningLinesPainter extends CustomPainter {
  final Color color;
  final Animation<double> controller;
  final int lineCount;

  _SpinningLinesPainter({
    required this.color,
    required this.controller,
    this.lineCount = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    for (int i = 0; i < lineCount; i++) {
      final angle = (2 * pi / lineCount) * i + controller.value * 2 * pi;
      final startOffset = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final endOffset = Offset(
        center.dx + (radius + size.width * 0.1) * cos(angle),
        center.dy + (radius + size.width * 0.1) * sin(angle),
      );

      canvas.drawLine(startOffset, endOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpinningLinesPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.controller != controller ||
        oldDelegate.lineCount != lineCount;
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  final AxisDirection direction;

  _TriangleClipper({required this.direction});

  @override
  Path getClip(Size size) {
    final path = Path();

    switch (direction) {
      case AxisDirection.up:
        path.moveTo(size.width / 2, 0); // Top center
        path.lineTo(size.width, size.height); // Bottom right
        path.lineTo(0, size.height); // Bottom left
        path.close();
        break;

      case AxisDirection.down:
        path.moveTo(0, 0); // Top left
        path.lineTo(size.width, 0); // Top right
        path.lineTo(size.width / 2, size.height); // Bottom center
        path.close();
        break;

      case AxisDirection.left:
        path.moveTo(size.width, 0); // Top right
        path.lineTo(0, size.height / 2); // Center left
        path.lineTo(size.width, size.height); // Bottom right
        path.close();
        break;

      case AxisDirection.right:
        path.moveTo(0, 0); // Top left
        path.lineTo(size.width, size.height / 2); // Center right
        path.lineTo(0, size.height); // Bottom left
        path.close();
        break;
    }

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return oldClipper is _TriangleClipper && oldClipper.direction != direction;
  }
}
