import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({required this.title, super.key, this.body});

  final String? body;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSpinner(),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  letterSpacing: 0,
                ),
              ),
              if (body != null && body!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _LoadingBars(),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSpinner extends StatefulWidget {
  const AppSpinner({super.key});

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1050),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 58,
        height: 58,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _SpinnerPainter(progress: _controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 4;
    final track = Paint()
      ..color = const Color(0xFFE6E7EA)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final arc = Paint()
      ..color = const Color(0xFF0B0B0C)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.28,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LoadingBars extends StatefulWidget {
  const _LoadingBars();

  @override
  State<_LoadingBars> createState() => _LoadingBarsState();
}

class _LoadingBarsState extends State<_LoadingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              _Bar(value: _barValue(index)),
          ],
        );
      },
    );
  }

  double _barValue(int index) {
    final shifted = (_controller.value + index * 0.22) % 1;
    return 0.35 + (math.sin(shifted * math.pi) * 0.65);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 18,
        height: 3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.2, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0C),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
