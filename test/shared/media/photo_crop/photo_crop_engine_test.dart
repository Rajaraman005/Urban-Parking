import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/media/photo_crop/photo_crop.dart';

void main() {
  group('PhotoCropEngine crop geometry', () {
    test('returns centered source rect for an untouched cover image', () {
      final rect = PhotoCropEngine.visibleSourceRect(
        offset: Offset.zero,
        baseScale: 0.5,
        userScale: 1,
        sourceSize: const Size(800, 600),
        viewportSize: const Size.square(300),
      );

      expect(rect.left, closeTo(100, 0.01));
      expect(rect.top, closeTo(0, 0.01));
      expect(rect.width, closeTo(600, 0.01));
      expect(rect.height, closeTo(600, 0.01));
    });

    test('shrinks source rect when user zooms in', () {
      final rect = PhotoCropEngine.visibleSourceRect(
        offset: Offset.zero,
        baseScale: 0.5,
        userScale: 2,
        sourceSize: const Size(800, 600),
        viewportSize: const Size.square(300),
      );

      expect(rect.left, closeTo(250, 0.01));
      expect(rect.top, closeTo(150, 0.01));
      expect(rect.width, closeTo(300, 0.01));
      expect(rect.height, closeTo(300, 0.01));
    });

    test('clamps panning to keep the crop viewport covered', () {
      final offset = PhotoCropEngine.clampOffset(
        offset: const Offset(500, -500),
        baseScale: 0.5,
        userScale: 1,
        sourceSize: const Size(800, 600),
        viewportSize: const Size.square(300),
      );

      expect(offset.dx, closeTo(50, 0.01));
      expect(offset.dy, closeTo(0, 0.01));
    });

    test('supports portrait source images without empty crop regions', () {
      final rect = PhotoCropEngine.visibleSourceRect(
        offset: Offset.zero,
        baseScale: 0.4,
        userScale: 1,
        sourceSize: const Size(600, 1000),
        viewportSize: const Size(240, 320),
      );

      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(100, 0.01));
      expect(rect.width, closeTo(600, 0.01));
      expect(rect.height, closeTo(800, 0.01));
    });
  });

  group('PhotoCropEngine MIME normalization', () {
    test('keeps JPEG and normalizes non-JPEG sources', () {
      expect(PhotoCropEngine.shouldNormalizeMime('image/jpeg'), isFalse);
      expect(PhotoCropEngine.shouldNormalizeMime('image/jpg'), isFalse);
      expect(PhotoCropEngine.shouldNormalizeMime('image/png'), isTrue);
      expect(PhotoCropEngine.shouldNormalizeMime('image/webp'), isTrue);
      expect(PhotoCropEngine.shouldNormalizeMime('image/heic'), isTrue);
    });
  });
}
