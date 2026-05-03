import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    _drawPath(canvas, _yellowPath(), const Color(0xFFFFC107));
    _drawPath(canvas, _redPath(), const Color(0xFFFF3D00));
    _drawPath(canvas, _greenPath(), const Color(0xFF4CAF50));
    _drawPath(canvas, _bluePath(), const Color(0xFF1976D2));
    canvas.restore();
  }

  void _drawPath(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _yellowPath() => Path()
    ..moveTo(43.611, 20.083)
    ..lineTo(42, 20.083)
    ..lineTo(42, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 28)
    ..lineTo(35.303, 28)
    ..cubicTo(33.654, 32.657, 29.223, 36, 24, 36)
    ..cubicTo(17.373, 36, 12, 30.627, 12, 24)
    ..cubicTo(12, 17.373, 17.373, 12, 24, 12)
    ..cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039)
    ..lineTo(37.618, 9.382)
    ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
    ..cubicTo(12.955, 4, 4, 12.955, 4, 24)
    ..cubicTo(4, 35.045, 12.955, 44, 24, 44)
    ..cubicTo(35.045, 44, 44, 35.045, 44, 24)
    ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
    ..close();

  Path _redPath() => Path()
    ..moveTo(6.306, 14.691)
    ..lineTo(12.877, 19.510)
    ..cubicTo(14.655, 15.108, 18.961, 12, 24, 12)
    ..cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039)
    ..lineTo(37.618, 9.382)
    ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
    ..cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691)
    ..close();

  Path _greenPath() => Path()
    ..moveTo(24, 44)
    ..cubicTo(29.166, 44, 33.86, 42.023, 37.409, 38.808)
    ..lineTo(31.219, 33.57)
    ..cubicTo(29.211, 35.091, 26.715, 36, 24, 36)
    ..cubicTo(18.798, 36, 14.381, 32.683, 12.717, 28.054)
    ..lineTo(6.195, 33.079)
    ..cubicTo(9.505, 39.556, 16.227, 44, 24, 44)
    ..close();

  Path _bluePath() => Path()
    ..moveTo(43.611, 20.083)
    ..lineTo(42, 20.083)
    ..lineTo(42, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 28)
    ..lineTo(35.303, 28)
    ..cubicTo(34.501, 30.26, 33.105, 32.179, 31.216, 33.571)
    ..lineTo(31.219, 33.569)
    ..lineTo(37.409, 38.807)
    ..cubicTo(36.971, 39.205, 44, 34, 44, 24)
    ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
    ..close();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
