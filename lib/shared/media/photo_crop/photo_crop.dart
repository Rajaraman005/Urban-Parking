import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

enum PhotoCropShape { circle, roundedRect }

enum PhotoCropPreset {
  square('Square', 1),
  landscape('Wide', 4 / 3),
  portrait('Tall', 3 / 4);

  const PhotoCropPreset(this.label, this.aspectRatio);

  final String label;
  final double aspectRatio;
}

class PhotoCropException implements Exception {
  const PhotoCropException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhotoCropConfig {
  const PhotoCropConfig({
    required this.aspectRatio,
    required this.cropShape,
    required this.maxBytes,
    required this.saveLabel,
    required this.title,
    this.fixedOutputSize,
    this.maxOutputDimension = 2400,
    this.minSourceDimension = 1,
    this.presets = const <PhotoCropPreset>[],
    this.reviewTitle = 'Review photos',
    this.reviewSaveLabel = 'Use photos',
  });

  factory PhotoCropConfig.avatar() {
    return const PhotoCropConfig(
      aspectRatio: 1,
      cropShape: PhotoCropShape.circle,
      fixedOutputSize: Size.square(1024),
      maxBytes: 5 * 1024 * 1024,
      maxOutputDimension: 1024,
      minSourceDimension: 256,
      saveLabel: 'Save photo',
      title: 'Edit profile photo',
    );
  }

  factory PhotoCropConfig.hostPhoto({
    PhotoCropPreset preset = PhotoCropPreset.landscape,
  }) {
    return PhotoCropConfig(
      aspectRatio: preset.aspectRatio,
      cropShape: PhotoCropShape.roundedRect,
      maxBytes: 9500000,
      maxOutputDimension: 2400,
      minSourceDimension: 480,
      presets: PhotoCropPreset.values,
      reviewSaveLabel: 'Use photos',
      reviewTitle: 'Review photos',
      saveLabel: 'Apply crop',
      title: 'Edit photo',
    );
  }

  final double aspectRatio;
  final PhotoCropShape cropShape;
  final Size? fixedOutputSize;
  final int maxBytes;
  final double maxOutputDimension;
  final int minSourceDimension;
  final List<PhotoCropPreset> presets;
  final String reviewSaveLabel;
  final String reviewTitle;
  final String saveLabel;
  final String title;

  PhotoCropConfig copyWith({
    double? aspectRatio,
    PhotoCropShape? cropShape,
    Size? fixedOutputSize,
    int? maxBytes,
    double? maxOutputDimension,
    int? minSourceDimension,
    List<PhotoCropPreset>? presets,
    String? reviewSaveLabel,
    String? reviewTitle,
    String? saveLabel,
    String? title,
  }) {
    return PhotoCropConfig(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      cropShape: cropShape ?? this.cropShape,
      fixedOutputSize: fixedOutputSize ?? this.fixedOutputSize,
      maxBytes: maxBytes ?? this.maxBytes,
      maxOutputDimension: maxOutputDimension ?? this.maxOutputDimension,
      minSourceDimension: minSourceDimension ?? this.minSourceDimension,
      presets: presets ?? this.presets,
      reviewSaveLabel: reviewSaveLabel ?? this.reviewSaveLabel,
      reviewTitle: reviewTitle ?? this.reviewTitle,
      saveLabel: saveLabel ?? this.saveLabel,
      title: title ?? this.title,
    );
  }
}

class PhotoCropSource {
  const PhotoCropSource({
    required this.bytes,
    required this.fileName,
    required this.height,
    required this.mimeType,
    required this.width,
  });

  final Uint8List bytes;
  final String fileName;
  final int height;
  final String mimeType;
  final int width;

  Size get size => Size(width.toDouble(), height.toDouble());
}

class CroppedPhotoResult {
  const CroppedPhotoResult({
    required this.bytes,
    required this.fileName,
    required this.height,
    required this.mimeType,
    required this.width,
  });

  final Uint8List bytes;
  final String fileName;
  final int height;
  final String mimeType;
  final int width;

  PhotoCropSource toSource() {
    return PhotoCropSource(
      bytes: bytes,
      fileName: fileName,
      height: height,
      mimeType: mimeType,
      width: width,
    );
  }
}

Future<CroppedPhotoResult?> openPhotoCropEditor({
  required BuildContext context,
  required PhotoCropConfig config,
  required PhotoCropSource source,
}) {
  return Navigator.of(context, rootNavigator: true).push<CroppedPhotoResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoCropEditorPage(config: config, source: source),
    ),
  );
}

Future<List<CroppedPhotoResult>?> openPhotoReviewTray({
  required BuildContext context,
  required PhotoCropConfig config,
  required List<PhotoCropSource> sources,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<List<CroppedPhotoResult>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoReviewTrayPage(config: config, sources: sources),
    ),
  );
}

class PhotoCropEngine {
  const PhotoCropEngine._();

  static const _jpegMimeType = 'image/jpeg';

  static Future<PhotoCropSource> sourceFromXFile(
    XFile file, {
    required PhotoCropConfig config,
    String fallbackFileName = 'photo.jpg',
    int pickerMaxDimension = 2600,
  }) async {
    var bytes = await file.readAsBytes();
    var fileName = file.name.trim().isEmpty ? fallbackFileName : file.name;
    var mimeType = file.mimeType ?? mimeTypeForName(fileName);

    if (bytes.isEmpty) {
      throw const PhotoCropException(
        'This photo is empty. Choose another one.',
      );
    }

    if (bytes.length > config.maxBytes || shouldNormalizeMime(mimeType)) {
      bytes = await compressForUpload(
        bytes,
        maxBytes: config.maxBytes,
        maxDimension: pickerMaxDimension,
      );
      fileName =
          '${fileStem(fileName, fallback: fileStem(fallbackFileName))}.jpg';
      mimeType = _jpegMimeType;
    }

    if (bytes.length > config.maxBytes) {
      throw const PhotoCropException(
        'This photo could not be optimized. Choose a smaller photo.',
      );
    }

    final size = await decodeImageSize(bytes);
    if (size.width < config.minSourceDimension ||
        size.height < config.minSourceDimension) {
      throw PhotoCropException(
        'Choose a photo at least ${config.minSourceDimension}px wide and tall.',
      );
    }

    return PhotoCropSource(
      bytes: bytes,
      fileName: fileName,
      height: size.height.round(),
      mimeType: mimeType,
      width: size.width.round(),
    );
  }

  static Future<CroppedPhotoResult> crop({
    required PhotoCropConfig config,
    required Rect sourceRect,
    required PhotoCropSource source,
  }) async {
    final codec = await ui.instantiateImageCodec(source.bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final outputSize = _outputSizeFor(config, sourceRect);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        sourceRect,
        Rect.fromLTWH(0, 0, outputSize.width, outputSize.height),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(
        outputSize.width.round(),
        outputSize.height.round(),
      );
      try {
        final pngBytes = await cropped.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (pngBytes == null) {
          throw const PhotoCropException('Could not edit this photo.');
        }

        final jpegBytes = await compressForUpload(
          pngBytes.buffer.asUint8List(
            pngBytes.offsetInBytes,
            pngBytes.lengthInBytes,
          ),
          maxBytes: config.maxBytes,
          maxDimension: math.max(outputSize.width, outputSize.height).round(),
        );
        if (jpegBytes.length > config.maxBytes) {
          throw const PhotoCropException(
            'This edit is too large. Try a tighter crop.',
          );
        }

        return CroppedPhotoResult(
          bytes: jpegBytes,
          fileName: '${fileStem(source.fileName)}.jpg',
          height: outputSize.height.round(),
          mimeType: _jpegMimeType,
          width: outputSize.width.round(),
        );
      } finally {
        cropped.dispose();
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  static Future<PhotoCropSource> rotateRight(
    PhotoCropSource source, {
    required int maxBytes,
  }) async {
    final codec = await ui.instantiateImageCodec(source.bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas
        ..translate(image.height.toDouble(), 0)
        ..rotate(math.pi / 2)
        ..drawImage(
          image,
          Offset.zero,
          Paint()..filterQuality = FilterQuality.high,
        );
      final picture = recorder.endRecording();
      final rotated = await picture.toImage(image.height, image.width);
      try {
        final pngBytes = await rotated.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (pngBytes == null) {
          throw const PhotoCropException('Could not rotate this photo.');
        }
        final bytes = await compressForUpload(
          pngBytes.buffer.asUint8List(
            pngBytes.offsetInBytes,
            pngBytes.lengthInBytes,
          ),
          maxBytes: maxBytes,
          maxDimension: math.max(image.width, image.height),
        );
        return PhotoCropSource(
          bytes: bytes,
          fileName: '${fileStem(source.fileName)}.jpg',
          height: image.width,
          mimeType: _jpegMimeType,
          width: image.height,
        );
      } finally {
        rotated.dispose();
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  static Future<Uint8List> compressForUpload(
    Uint8List bytes, {
    required int maxBytes,
    required int maxDimension,
  }) async {
    final profiles = [
      (dimension: maxDimension.clamp(720, 2600), quality: 90),
      (dimension: 2200, quality: 84),
      (dimension: 1800, quality: 78),
      (dimension: 1500, quality: 72),
      (dimension: 1200, quality: 66),
      (dimension: 1000, quality: 60),
      (dimension: 850, quality: 54),
      (dimension: 720, quality: 48),
    ];

    Uint8List best = bytes;
    for (final profile in profiles) {
      final compressed = await FlutterImageCompress.compressWithList(
        best,
        format: CompressFormat.jpeg,
        minHeight: profile.dimension,
        minWidth: profile.dimension,
        quality: profile.quality,
      );
      if (compressed.isEmpty) continue;
      best = compressed;
      if (best.length <= maxBytes) break;
    }
    return best;
  }

  static Future<Size> decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      return Size(image.width.toDouble(), image.height.toDouble());
    } finally {
      image.dispose();
    }
  }

  static Rect visibleSourceRect({
    required Offset offset,
    required double baseScale,
    required double userScale,
    required Size sourceSize,
    required Size viewportSize,
  }) {
    final effectiveScale = baseScale * userScale;
    final displayWidth = sourceSize.width * effectiveScale;
    final displayHeight = sourceSize.height * effectiveScale;
    final left = (viewportSize.width - displayWidth) / 2 + offset.dx;
    final top = (viewportSize.height - displayHeight) / 2 + offset.dy;

    final sourceLeft = ((0 - left) / effectiveScale).clamp(
      0.0,
      sourceSize.width,
    );
    final sourceTop = ((0 - top) / effectiveScale).clamp(
      0.0,
      sourceSize.height,
    );
    final sourceWidth = (viewportSize.width / effectiveScale).clamp(
      1.0,
      sourceSize.width - sourceLeft,
    );
    final sourceHeight = (viewportSize.height / effectiveScale).clamp(
      1.0,
      sourceSize.height - sourceTop,
    );

    return Rect.fromLTWH(sourceLeft, sourceTop, sourceWidth, sourceHeight);
  }

  static Offset clampOffset({
    required Offset offset,
    required double baseScale,
    required double userScale,
    required Size sourceSize,
    required Size viewportSize,
  }) {
    final displayWidth = sourceSize.width * baseScale * userScale;
    final displayHeight = sourceSize.height * baseScale * userScale;
    final maxDx = math.max(0, (displayWidth - viewportSize.width) / 2);
    final maxDy = math.max(0, (displayHeight - viewportSize.height) / 2);
    return Offset(
      offset.dx.clamp(-maxDx, maxDx).toDouble(),
      offset.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  static String mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return _jpegMimeType;
  }

  static bool shouldNormalizeMime(String mimeType) {
    final normalized = mimeType.toLowerCase();
    return normalized != 'image/jpeg' && normalized != 'image/jpg';
  }

  static String fileStem(String name, {String fallback = 'photo'}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;
    final dot = trimmed.lastIndexOf('.');
    return dot <= 0 ? trimmed : trimmed.substring(0, dot);
  }

  static Size _outputSizeFor(PhotoCropConfig config, Rect sourceRect) {
    final fixed = config.fixedOutputSize;
    if (fixed != null) return fixed;

    final largestSide = math.max(sourceRect.width, sourceRect.height);
    final scale = largestSide > config.maxOutputDimension
        ? config.maxOutputDimension / largestSide
        : 1.0;
    final width = math.max(1, (sourceRect.width * scale).round()).toDouble();
    final height = math.max(1, (sourceRect.height * scale).round()).toDouble();
    return Size(width, height);
  }
}

class PhotoCropEditorPage extends StatefulWidget {
  const PhotoCropEditorPage({
    required this.config,
    required this.source,
    super.key,
  });

  final PhotoCropConfig config;
  final PhotoCropSource source;

  @override
  State<PhotoCropEditorPage> createState() => _PhotoCropEditorPageState();
}

class _PhotoCropEditorPageState extends State<PhotoCropEditorPage> {
  static const _background = Color(0xFF0B0B0C);

  late final PhotoCropSource _originalSource;
  late PhotoCropSource _source;
  Offset _offset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  Offset _startOffset = Offset.zero;
  Size _lastViewportSize = Size.zero;
  double _baseScale = 1;
  double _scale = 1;
  double _startScale = 1;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _originalSource = widget.source;
    _source = widget.source;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _background,
        systemNavigationBarColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _CropTopBar(
                busy: _processing,
                onClose: () => Navigator.of(context).pop(),
                onRotate: _processing ? null : _rotateRight,
                onReset: _processing ? null : _resetTransform,
                title: config.title,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: _processing
                    ? const LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: Color(0xFFB9F45E),
                      )
                    : const SizedBox(height: 2),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: RepaintBoundary(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final viewportSize = _viewportSizeFor(
                            constraints.biggest,
                            config.aspectRatio,
                          );
                          _syncViewport(viewportSize);
                          return _CropViewport(
                            baseScale: _baseScale,
                            config: config,
                            offset: _offset,
                            onScaleEnd: (_) => _clampCurrentOffset(),
                            onScaleStart: _handleScaleStart,
                            onScaleUpdate: _handleScaleUpdate,
                            scale: _scale,
                            source: _source,
                            viewportSize: viewportSize,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _PrimaryCropButton(
                  busy: _processing,
                  label: config.saveLabel,
                  onPressed: _processing ? null : _saveCrop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncViewport(Size viewportSize) {
    if (viewportSize == Size.zero || viewportSize == _lastViewportSize) {
      return;
    }
    _lastViewportSize = viewportSize;
    _baseScale = math.max(
      viewportSize.width / _source.width,
      viewportSize.height / _source.height,
    );
    _offset = PhotoCropEngine.clampOffset(
      offset: _offset,
      baseScale: _baseScale,
      userScale: _scale,
      sourceSize: _source.size,
      viewportSize: viewportSize,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _startFocalPoint = details.localFocalPoint;
    _startOffset = _offset;
    _startScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final nextScale = (_startScale * details.scale).clamp(1.0, 5.0);
    final nextOffset =
        _startOffset + details.localFocalPoint - _startFocalPoint;
    setState(() {
      _scale = nextScale;
      _offset = PhotoCropEngine.clampOffset(
        offset: nextOffset,
        baseScale: _baseScale,
        userScale: _scale,
        sourceSize: _source.size,
        viewportSize: _lastViewportSize,
      );
    });
  }

  void _clampCurrentOffset() {
    setState(() {
      _offset = PhotoCropEngine.clampOffset(
        offset: _offset,
        baseScale: _baseScale,
        userScale: _scale,
        sourceSize: _source.size,
        viewportSize: _lastViewportSize,
      );
    });
  }

  void _resetTransform() {
    setState(() {
      _source = _originalSource;
      _scale = 1;
      _offset = Offset.zero;
      _lastViewportSize = Size.zero;
      _error = null;
    });
  }

  Future<void> _rotateRight() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final rotated = await PhotoCropEngine.rotateRight(
        _source,
        maxBytes: widget.config.maxBytes,
      );
      if (!mounted) return;
      setState(() {
        _source = rotated;
        _scale = 1;
        _offset = Offset.zero;
        _lastViewportSize = Size.zero;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _saveCrop() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final sourceRect = PhotoCropEngine.visibleSourceRect(
        offset: _offset,
        baseScale: _baseScale,
        userScale: _scale,
        sourceSize: _source.size,
        viewportSize: _lastViewportSize,
      );
      final result = await PhotoCropEngine.crop(
        config: widget.config,
        source: _source,
        sourceRect: sourceRect,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _messageFor(Object error) {
    if (error is PhotoCropException) return error.message;
    return 'Could not edit this photo. Please try again.';
  }

  Size _viewportSizeFor(Size available, double aspectRatio) {
    if (available.width <= 0 || available.height <= 0) return Size.zero;
    var width = available.width;
    var height = width / aspectRatio;
    if (height > available.height) {
      height = available.height;
      width = height * aspectRatio;
    }
    return Size(width, height);
  }
}

class PhotoReviewTrayPage extends StatefulWidget {
  const PhotoReviewTrayPage({
    required this.config,
    required this.sources,
    super.key,
  });

  final PhotoCropConfig config;
  final List<PhotoCropSource> sources;

  @override
  State<PhotoReviewTrayPage> createState() => _PhotoReviewTrayPageState();
}

class _PhotoReviewTrayPageState extends State<PhotoReviewTrayPage> {
  late final List<PhotoCropSource> _photos;
  PhotoCropPreset _preset = PhotoCropPreset.landscape;
  int _selectedIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photos = List<PhotoCropSource>.from(widget.sources);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _photos.isEmpty ? null : _photos[_selectedIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B0B0C),
        surfaceTintColor: Colors.transparent,
        title: Text(widget.config.reviewTitle),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: _PrimaryCropButton(
          busy: _busy,
          label: widget.config.reviewSaveLabel,
          onPressed: _photos.isEmpty || _busy ? null : _returnPhotos,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: selected == null
                    ? const Center(
                        child: Text(
                          'No photos selected',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: RepaintBoundary(
                              child: _ReviewPreview(photo: selected),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PresetSelector(
                            selected: _preset,
                            onSelected: _busy
                                ? null
                                : (preset) => setState(() => _preset = preset),
                          ),
                          const SizedBox(height: 12),
                          _ReviewActions(
                            canMoveLeft: _selectedIndex > 0,
                            canMoveRight: _selectedIndex < _photos.length - 1,
                            onCrop: _busy ? null : _cropSelected,
                            onMoveLeft: _busy ? null : () => _moveSelected(-1),
                            onMoveRight: _busy ? null : () => _moveSelected(1),
                            onRemove: _busy ? null : _removeSelected,
                          ),
                        ],
                      ),
              ),
            ),
            if (_photos.isNotEmpty)
              RepaintBoundary(
                child: SizedBox(
                  height: 94,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return _ReviewThumbnail(
                        index: index,
                        photo: _photos[index],
                        selected: index == _selectedIndex,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selectedIndex = index),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemCount: _photos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropSelected() async {
    final source = _photos[_selectedIndex];
    final result = await openPhotoCropEditor(
      context: context,
      config: PhotoCropConfig.hostPhoto(preset: _preset),
      source: source,
    );
    if (!mounted || result == null) return;
    setState(() => _photos[_selectedIndex] = result.toSource());
  }

  void _moveSelected(int delta) {
    final nextIndex = _selectedIndex + delta;
    if (nextIndex < 0 || nextIndex >= _photos.length) return;
    final photo = _photos.removeAt(_selectedIndex);
    _photos.insert(nextIndex, photo);
    setState(() => _selectedIndex = nextIndex);
  }

  void _removeSelected() {
    if (_photos.isEmpty) return;
    _photos.removeAt(_selectedIndex);
    setState(() {
      if (_selectedIndex >= _photos.length) {
        _selectedIndex = math.max(0, _photos.length - 1);
      }
    });
  }

  void _returnPhotos() {
    setState(() => _busy = true);
    final results = _photos
        .map(
          (photo) => CroppedPhotoResult(
            bytes: photo.bytes,
            fileName: photo.fileName,
            height: photo.height,
            mimeType: photo.mimeType,
            width: photo.width,
          ),
        )
        .toList(growable: false);
    Navigator.of(context).pop(results);
  }
}

class _CropTopBar extends StatelessWidget {
  const _CropTopBar({
    required this.busy,
    required this.onClose,
    required this.onReset,
    required this.onRotate,
    required this.title,
  });

  final bool busy;
  final VoidCallback onClose;
  final VoidCallback? onReset;
  final VoidCallback? onRotate;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          _CropToolbarAction(
            icon: Icons.close_rounded,
            label: 'Close',
            onPressed: busy ? null : onClose,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CropToolbarAction(
            icon: Icons.rotate_90_degrees_cw_rounded,
            label: 'Rotate photo',
            onPressed: onRotate,
          ),
          const SizedBox(width: 8),
          _CropToolbarAction(
            icon: Icons.restart_alt_rounded,
            label: 'Reset photo',
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _CropToolbarAction extends StatelessWidget {
  const _CropToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              icon,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.34),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _CropViewport extends StatelessWidget {
  const _CropViewport({
    required this.baseScale,
    required this.config,
    required this.offset,
    required this.onScaleEnd,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.scale,
    required this.source,
    required this.viewportSize,
  });

  final double baseScale;
  final PhotoCropConfig config;
  final Offset offset;
  final GestureScaleEndCallback onScaleEnd;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final double scale;
  final PhotoCropSource source;
  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    final effectiveScale = baseScale * scale;
    final displaySize = Size(
      source.width * effectiveScale,
      source.height * effectiveScale,
    );
    final cropRadius = config.cropShape == PhotoCropShape.circle
        ? BorderRadius.circular(viewportSize.width / 2)
        : BorderRadius.circular(26);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pinch and drag to frame the photo',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleEnd: onScaleEnd,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: cropRadius,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: cropRadius,
              child: SizedBox(
                width: viewportSize.width,
                height: viewportSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
                    Positioned(
                      left:
                          (viewportSize.width - displaySize.width) / 2 +
                          offset.dx,
                      top:
                          (viewportSize.height - displaySize.height) / 2 +
                          offset.dy,
                      width: displaySize.width,
                      height: displaySize.height,
                      child: Image.memory(
                        source.bytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const _RuleOfThirdsOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleOfThirdsOverlay extends StatelessWidget {
  const _RuleOfThirdsOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _RuleOfThirdsPainter()));
  }
}

class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(0, size.height / 3),
        Offset(size.width, size.height / 3),
        paint,
      )
      ..drawLine(
        Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrimaryCropButton extends StatelessWidget {
  const _PrimaryCropButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.46),
        disabledForegroundColor: const Color(
          0xFF0B0B0C,
        ).withValues(alpha: 0.46),
        foregroundColor: const Color(0xFF0B0B0C),
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                color: Color(0xFF0B0B0C),
                strokeWidth: 2.6,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
    );
  }
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview({required this.photo});

  final PhotoCropSource photo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(
          photo.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({required this.onSelected, required this.selected});

  final ValueChanged<PhotoCropPreset>? onSelected;
  final PhotoCropPreset selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final preset in PhotoCropPreset.values) ...[
          Expanded(
            child: _PresetChip(
              label: preset.label,
              selected: preset == selected,
              onTap: onSelected == null ? null : () => onSelected!(preset),
            ),
          ),
          if (preset != PhotoCropPreset.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0B0B0C) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF0B0B0C)
                  : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF0B0B0C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onCrop,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onRemove,
  });

  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback? onCrop;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCrop,
            icon: const Icon(Icons.crop_rounded),
            label: const Text('Crop'),
            style: _outlineStyle(),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Move left',
          onPressed: canMoveLeft ? onMoveLeft : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Move right',
          onPressed: canMoveRight ? onMoveRight : null,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Remove photo',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  ButtonStyle _outlineStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0B0B0C),
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }
}

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail({
    required this.index,
    required this.onTap,
    required this.photo,
    required this.selected,
  });

  final int index;
  final VoidCallback? onTap;
  final PhotoCropSource photo;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Photo ${index + 1}',
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF0B0B0C)
                  : const Color(0xFFE5E7EB),
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 76,
              height: 76,
              child: Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
