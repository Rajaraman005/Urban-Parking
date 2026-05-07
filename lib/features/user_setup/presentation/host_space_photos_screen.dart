import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/user_setup_state.dart';
import 'user_setup_controller.dart';
import 'widgets/host_setup_app_bar.dart';

class HostSpacePhotosScreen extends ConsumerStatefulWidget {
  const HostSpacePhotosScreen({super.key});

  @override
  ConsumerState<HostSpacePhotosScreen> createState() =>
      _HostSpacePhotosScreenState();
}

class _HostSpacePhotosScreenState extends ConsumerState<HostSpacePhotosScreen> {
  static const _maxPhotoCount = 5;
  static const _maxUploadPhotoBytes = 9.5 * 1024 * 1024;
  static const _pickerImageQuality = 96;

  final _imagePicker = ImagePicker();

  bool _isEnsuringDraft = false;
  bool _isPreparingPhotos = false;
  bool _isUploading = false;
  bool _isContinuing = false;
  bool _isReordering = false;
  int _processedUploadCount = 0;
  int _totalUploadCount = 0;
  final List<_PendingHostPhoto> _pendingPhotos = [];
  String? _deletingPhotoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final setupValue = ref.watch(userSetupControllerProvider);
    final draft = setupValue.value?.draft;

    if ((setupValue.isLoading || _isEnsuringDraft) && draft == null) {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _backToPricing),
        child: const StateView(
          title: 'Preparing photos',
          body: 'Loading your draft parking space.',
          isLoading: true,
        ),
      );
    }

    final photos = draft?.photos ?? const <HostListingPhoto>[];
    final remainingSlots =
        (_maxPhotoCount - photos.length - _pendingPhotos.length).clamp(
          0,
          _maxPhotoCount,
        );
    final canAdd = remainingSlots > 0 && !_isUploading && !_isPreparingPhotos;
    final hasLocalPhotos = photos.isNotEmpty || _pendingPhotos.isNotEmpty;
    final uploadStatusLabel = _uploadStatusLabel;
    final bottomActionLabel = _pendingPhotos.isEmpty
        ? 'Continue to review'
        : 'Upload ${_photoWord(_pendingPhotos.length)}';
    final bottomAction = _pendingPhotos.isEmpty
        ? () => _continue(photos)
        : _uploadPendingPhotos;
    final canContinueToReview = _pendingPhotos.isEmpty && photos.length >= 2;
    final canRunBottomAction = _pendingPhotos.isNotEmpty || canContinueToReview;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: HostSetupAppBar(onBack: _backToPricing),
      bottomNavigationBar: _PhotosBottomAction(
        isBusy: _isContinuing || _isUploading || _isPreparingPhotos,
        label: bottomActionLabel,
        onPressed:
            _isContinuing ||
                _isUploading ||
                _isPreparingPhotos ||
                !canRunBottomAction
            ? null
            : bottomAction,
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StepEyebrow('Step 3 of 4'),
                  const SizedBox(height: 14),
                  _PhotoCountPanel(
                    count: photos.length,
                    pendingCount: _pendingPhotos.length,
                  ),
                  const SizedBox(height: 14),
                  if (!hasLocalPhotos)
                    Expanded(
                      child: _PhotoUploadPanel(
                        hasPhotos: false,
                        isBusy: _isUploading || _isPreparingPhotos,
                        onTap: canAdd
                            ? () => _showPhotoSourcePicker(
                                remainingSlots: remainingSlots,
                              )
                            : null,
                        statusLabel: _isPreparingPhotos
                            ? 'Preparing photos'
                            : uploadStatusLabel,
                      ),
                    )
                  else ...[
                    for (var index = 0; index < photos.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PhotoTile(
                          canMoveDown:
                              index < photos.length - 1 &&
                              !_isReordering &&
                              !_isUploading,
                          canMoveUp:
                              index > 0 && !_isReordering && !_isUploading,
                          deleting: _deletingPhotoId == photos[index].id,
                          onDelete: _isUploading
                              ? null
                              : () => _deletePhoto(photos[index]),
                          onMoveDown: () =>
                              _movePhoto(photos, index, index + 1),
                          onMoveUp: () => _movePhoto(photos, index, index - 1),
                          photo: photos[index],
                        ),
                      ),
                    for (final pendingPhoto in _pendingPhotos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingPhotoTile(
                          onEdit: _isUploading || _isPreparingPhotos
                              ? null
                              : () => _showPhotoEditOptions(pendingPhoto),
                          onRemove: _isUploading || _isPreparingPhotos
                              ? null
                              : () => _removePendingPhoto(pendingPhoto.id),
                          photo: pendingPhoto,
                        ),
                      ),
                    if (remainingSlots > 0)
                      _PhotoUploadPanel(
                        hasPhotos: true,
                        isBusy: _isUploading || _isPreparingPhotos,
                        onTap: canAdd
                            ? () => _showPhotoSourcePicker(
                                remainingSlots: remainingSlots,
                              )
                            : null,
                        statusLabel: _isPreparingPhotos
                            ? 'Preparing photos'
                            : uploadStatusLabel,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _backToPricing() {
    context.go('/setup/host-pricing');
  }

  Future<void> _bootstrap() async {
    await _ensureDraft();
    await _recoverLostPhotoSelections();
  }

  Future<void> _ensureDraft() async {
    if (_isEnsuringDraft) return;
    final setup = ref.read(userSetupControllerProvider).value;
    if (setup?.draft != null) return;
    setState(() => _isEnsuringDraft = true);
    try {
      await ref.read(userSetupControllerProvider.notifier).startHostListing();
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isEnsuringDraft = false);
    }
  }

  Future<void> _showPhotoSourcePicker({required int remainingSlots}) async {
    if (_isUploading || _isPreparingPhotos) return;
    if (remainingSlots <= 0) {
      AppToast.info(context, 'You can upload up to $_maxPhotoCount photos.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  minLeadingWidth: 28,
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  minLeadingWidth: 28,
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    remainingSlots == 1
                        ? 'Choose 1 photo'
                        : 'Choose up to $remainingSlots photos',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || source == null) return;
    await _pickAndStagePhotos(source, remainingSlots: remainingSlots);
  }

  Future<void> _pickAndStagePhotos(
    ImageSource source, {
    required int remainingSlots,
  }) async {
    try {
      final picked = source == ImageSource.gallery
          ? await _imagePicker.pickMultiImage(
              imageQuality: _pickerImageQuality,
              limit: remainingSlots,
              requestFullMetadata: false,
            )
          : await _pickSingleImage(source);
      if (picked.isEmpty) return;

      await _stagePickedPhotos(picked, remainingSlots: remainingSlots);
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    }
  }

  Future<List<XFile>> _pickSingleImage(ImageSource source) async {
    final pickedPhoto = await _imagePicker.pickImage(
      source: source,
      imageQuality: _pickerImageQuality,
      requestFullMetadata: false,
    );
    return pickedPhoto == null ? const <XFile>[] : [pickedPhoto];
  }

  Future<void> _recoverLostPhotoSelections() async {
    try {
      final lostData = await _imagePicker.retrieveLostData();
      if (lostData.isEmpty || !mounted) return;
      if (lostData.exception != null) {
        AppToast.error(context, 'Could not recover selected photos.');
        return;
      }

      final picked =
          lostData.files ?? [if (lostData.file != null) lostData.file!];
      if (picked.isEmpty) return;

      final photos =
          ref.read(userSetupControllerProvider).value?.draft?.photos ??
          const <HostListingPhoto>[];
      final remainingSlots =
          (_maxPhotoCount - photos.length - _pendingPhotos.length).clamp(
            0,
            _maxPhotoCount,
          );
      if (remainingSlots <= 0) return;

      AppToast.info(context, 'Restoring selected photos.');
      await _stagePickedPhotos(picked, remainingSlots: remainingSlots);
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    }
  }

  Future<void> _stagePickedPhotos(
    List<XFile> picked, {
    required int remainingSlots,
  }) async {
    final stageQueue = picked.take(remainingSlots).toList(growable: false);
    final skippedCount = picked.length - stageQueue.length;
    if (stageQueue.isEmpty) return;
    if (skippedCount > 0 && mounted) {
      AppToast.info(
        context,
        'Only ${_photoWord(remainingSlots)} can be added.',
      );
    }

    final stagedPhotos = <_PendingHostPhoto>[];
    var failedCount = 0;
    setState(() => _isPreparingPhotos = true);
    try {
      for (final pickedPhoto in stageQueue) {
        try {
          stagedPhotos.add(await _pendingPhotoFromPickedImage(pickedPhoto));
        } catch (_) {
          failedCount += 1;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingPhotos.addAll(stagedPhotos);
          _isPreparingPhotos = false;
        });
      }
    }

    if (!mounted) return;
    if (stagedPhotos.isNotEmpty) {
      AppToast.info(context, '${_photoWord(stagedPhotos.length)} ready');
    }
    if (failedCount > 0) {
      AppToast.error(context, '$failedCount photo could not be prepared.');
    }
  }

  Future<_PendingHostPhoto> _pendingPhotoFromPickedImage(XFile picked) async {
    final candidate = await _candidateFromPickedImage(picked);
    return _PendingHostPhoto(
      candidate: candidate,
      id: '${DateTime.now().microsecondsSinceEpoch}-${picked.name}',
      originalCandidate: candidate,
    );
  }

  void _removePendingPhoto(String id) {
    setState(() => _pendingPhotos.removeWhere((photo) => photo.id == id));
  }

  Future<void> _uploadPendingPhotos() async {
    final uploadQueue = List<_PendingHostPhoto>.from(_pendingPhotos);
    if (uploadQueue.isEmpty) return;

    var uploadedCount = 0;
    var failedCount = 0;
    Object? lastError;
    final failureMessages = <String>{};
    setState(() {
      _isUploading = true;
      _processedUploadCount = 0;
      _totalUploadCount = uploadQueue.length;
    });

    try {
      for (final pendingPhoto in uploadQueue) {
        if (!mounted) break;
        try {
          await _uploadPendingPhotoWithRetry(pendingPhoto.candidate);
          uploadedCount += 1;
          if (mounted) {
            setState(
              () => _pendingPhotos.removeWhere(
                (photo) => photo.id == pendingPhoto.id,
              ),
            );
          }
        } catch (error) {
          failedCount += 1;
          lastError = error;
          failureMessages.add(_errorMessage(error));
        } finally {
          if (mounted) {
            setState(() => _processedUploadCount += 1);
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _processedUploadCount = 0;
          _totalUploadCount = 0;
        });
      }
    }

    if (!mounted) return;
    if (failedCount > 0) {
      await _recoverDraftAfterUploadFailure();
      if (!mounted) return;
    }
    if (uploadedCount == uploadQueue.length) {
      AppToast.success(context, '${_photoWord(uploadedCount)} uploaded');
    } else if (uploadedCount > 0) {
      final reason = failureMessages.isEmpty
          ? 'Try again.'
          : failureMessages.first;
      AppToast.error(
        context,
        '$uploadedCount uploaded. $failedCount still need upload. $reason',
      );
    } else {
      AppToast.error(context, _errorMessage(lastError ?? Object()));
    }
  }

  Future<void> _recoverDraftAfterUploadFailure() async {
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .startHostListing(resumeStep: 'host_photos');
    } catch (_) {
      // Keep the staged photos visible; the next retry will rehydrate the draft.
    }
  }

  Future<void> _uploadPendingPhotoWithRetry(
    HostPhotoUploadCandidate candidate,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await ref
            .read(userSetupControllerProvider.notifier)
            .uploadHostPhoto(candidate);
        return;
      } catch (error) {
        lastError = error;
        if (!_shouldRetryUpload(error) || attempt == 2) break;
        await Future<void>.delayed(Duration(milliseconds: 550 * (attempt + 1)));
      }
    }
    throw lastError ?? Object();
  }

  bool _shouldRetryUpload(Object error) {
    if (error is ValidationFailure || error is AuthFailure) return false;
    if (error is AppFailure) return error.retryable;
    return true;
  }

  Future<HostPhotoUploadCandidate> _candidateFromPickedImage(
    XFile picked,
  ) async {
    var bytes = await picked.readAsBytes();
    var mimeType = picked.mimeType ?? _mimeTypeForName(picked.name);
    var fileName = picked.name.isEmpty ? 'parking-space.jpg' : picked.name;

    if (bytes.length > _maxUploadPhotoBytes || _shouldNormalizeMime(mimeType)) {
      bytes = await _compressForUpload(bytes);
      mimeType = 'image/jpeg';
      fileName = '${_fileStem(fileName)}.jpg';
    }

    if (bytes.length > _maxUploadPhotoBytes) {
      throw const ValidationFailure(
        'This photo could not be optimized. Try a different photo.',
        code: 'host_photo_optimize_failed',
      );
    }

    final dimensions = await _decodeImageSize(bytes);
    return HostPhotoUploadCandidate(
      bytes: bytes,
      fileName: fileName,
      height: dimensions.height.round(),
      mimeType: mimeType,
      width: dimensions.width.round(),
    );
  }

  bool _shouldNormalizeMime(String mimeType) {
    final normalized = mimeType.toLowerCase();
    return normalized == 'image/heic' || normalized == 'image/heif';
  }

  Future<Uint8List> _compressForUpload(Uint8List bytes) async {
    const profiles = [
      (maxDimension: 2600, quality: 88),
      (maxDimension: 2200, quality: 82),
      (maxDimension: 1800, quality: 76),
      (maxDimension: 1500, quality: 70),
      (maxDimension: 1200, quality: 64),
      (maxDimension: 1000, quality: 58),
      (maxDimension: 850, quality: 52),
      (maxDimension: 720, quality: 46),
    ];

    Uint8List best = bytes;
    for (final profile in profiles) {
      final compressed = await FlutterImageCompress.compressWithList(
        best,
        format: CompressFormat.jpeg,
        minHeight: profile.maxDimension,
        minWidth: profile.maxDimension,
        quality: profile.quality,
      );
      if (compressed.isEmpty) continue;
      best = compressed;
      if (best.length <= _maxUploadPhotoBytes) break;
    }
    return best;
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      return Size(image.width.toDouble(), image.height.toDouble());
    } finally {
      image.dispose();
    }
  }

  Future<void> _showPhotoEditOptions(_PendingHostPhoto photo) async {
    final action = await showModalBottomSheet<_PhotoEditAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.crop_square_rounded),
                  minLeadingWidth: 28,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const _PhotoEditAction.crop(_PhotoCropPreset.square)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Square crop',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.crop_16_9_rounded),
                  minLeadingWidth: 28,
                  onTap: () => Navigator.of(context).pop(
                    const _PhotoEditAction.crop(_PhotoCropPreset.landscape),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Landscape crop',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.crop_portrait_rounded),
                  minLeadingWidth: 28,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const _PhotoEditAction.crop(_PhotoCropPreset.portrait)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Portrait crop',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  minLeadingWidth: 28,
                  onTap: () =>
                      Navigator.of(context).pop(const _PhotoEditAction.reset()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text(
                    'Reset photo',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _CropPhotoEditAction(:final preset):
        await _applyPendingCrop(photo, preset);
      case _ResetPhotoEditAction():
        _resetPendingPhoto(photo);
    }
  }

  Future<void> _applyPendingCrop(
    _PendingHostPhoto photo,
    _PhotoCropPreset preset,
  ) async {
    setState(() => _isPreparingPhotos = true);
    try {
      final nextCandidate = await _centerCropCandidate(
        photo.originalCandidate,
        preset.aspectRatio,
      );
      if (!mounted) return;
      setState(() {
        final index = _pendingPhotos.indexWhere(
          (entry) => entry.id == photo.id,
        );
        if (index != -1) {
          _pendingPhotos[index] = photo.copyWith(candidate: nextCandidate);
        }
      });
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isPreparingPhotos = false);
    }
  }

  void _resetPendingPhoto(_PendingHostPhoto photo) {
    setState(() {
      final index = _pendingPhotos.indexWhere((entry) => entry.id == photo.id);
      if (index != -1) {
        _pendingPhotos[index] = photo.copyWith(
          candidate: photo.originalCandidate,
        );
      }
    });
  }

  Future<HostPhotoUploadCandidate> _centerCropCandidate(
    HostPhotoUploadCandidate candidate,
    double aspectRatio,
  ) async {
    final codec = await ui.instantiateImageCodec(candidate.bytes);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    try {
      final sourceRatio = source.width / source.height;
      late final Rect sourceRect;
      if (sourceRatio > aspectRatio) {
        final cropWidth = source.height * aspectRatio;
        sourceRect = Rect.fromLTWH(
          (source.width - cropWidth) / 2,
          0,
          cropWidth,
          source.height.toDouble(),
        );
      } else {
        final cropHeight = source.width / aspectRatio;
        sourceRect = Rect.fromLTWH(
          0,
          (source.height - cropHeight) / 2,
          source.width.toDouble(),
          cropHeight,
        );
      }

      const maxOutputDimension = 2400.0;
      final largestSourceSide = sourceRect.width > sourceRect.height
          ? sourceRect.width
          : sourceRect.height;
      final scale = largestSourceSide > maxOutputDimension
          ? maxOutputDimension / largestSourceSide
          : 1.0;
      final outputWidth = (sourceRect.width * scale)
          .round()
          .clamp(1, 10000)
          .toInt();
      final outputHeight = (sourceRect.height * scale)
          .round()
          .clamp(1, 10000)
          .toInt();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        source,
        sourceRect,
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(outputWidth, outputHeight);
      try {
        final pngBytes = await croppedImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (pngBytes == null) {
          throw const ValidationFailure(
            'Could not edit this photo.',
            code: 'host_photo_edit_failed',
          );
        }
        final jpegBytes = await _compressForUpload(
          pngBytes.buffer.asUint8List(
            pngBytes.offsetInBytes,
            pngBytes.lengthInBytes,
          ),
        );
        if (jpegBytes.length > _maxUploadPhotoBytes) {
          throw const ValidationFailure(
            'This edit is too large. Try a smaller crop.',
            code: 'host_photo_edit_too_large',
          );
        }
        return HostPhotoUploadCandidate(
          bytes: jpegBytes,
          fileName: '${_fileStem(candidate.fileName)}.jpg',
          height: outputHeight,
          mimeType: 'image/jpeg',
          width: outputWidth,
        );
      } finally {
        croppedImage.dispose();
        picture.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  Future<void> _deletePhoto(HostListingPhoto photo) async {
    if (_deletingPhotoId != null || _isUploading) return;
    setState(() => _deletingPhotoId = photo.id);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .deleteHostPhoto(photo.id);
      if (mounted) AppToast.info(context, 'Photo removed');
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _deletingPhotoId = null);
    }
  }

  Future<void> _movePhoto(
    List<HostListingPhoto> photos,
    int from,
    int to,
  ) async {
    if (_isReordering) return;
    final ids = photos.map((photo) => photo.id).toList(growable: true);
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    setState(() => _isReordering = true);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .reorderHostPhotos(ids);
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  Future<void> _continue(List<HostListingPhoto> photos) async {
    if (_isUploading) {
      AppToast.info(context, 'Wait for photos to finish uploading.');
      return;
    }
    if (_pendingPhotos.isNotEmpty) {
      AppToast.info(context, 'Upload selected photos before review.');
      return;
    }
    if (photos.length < 2) {
      AppToast.error(context, 'Add at least two photos.');
      return;
    }
    setState(() => _isContinuing = true);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .completeHostPhotosStep();
      if (mounted) context.go('/setup/host-review');
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _fileStem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? 'parking-space' : name.substring(0, dot);
  }

  String? get _uploadStatusLabel {
    if (!_isUploading) return null;
    if (_totalUploadCount <= 1) return 'Uploading photo';
    final current = (_processedUploadCount + 1).clamp(1, _totalUploadCount);
    return 'Uploading $current of $_totalUploadCount';
  }

  String _photoWord(int count) {
    return count == 1 ? '1 photo' : '$count photos';
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }
}

class _PendingHostPhoto {
  const _PendingHostPhoto({
    required this.candidate,
    required this.id,
    required this.originalCandidate,
  });

  final HostPhotoUploadCandidate candidate;
  final String id;
  final HostPhotoUploadCandidate originalCandidate;

  _PendingHostPhoto copyWith({HostPhotoUploadCandidate? candidate}) {
    return _PendingHostPhoto(
      candidate: candidate ?? this.candidate,
      id: id,
      originalCandidate: originalCandidate,
    );
  }
}

enum _PhotoCropPreset {
  square(1),
  landscape(4 / 3),
  portrait(3 / 4);

  const _PhotoCropPreset(this.aspectRatio);

  final double aspectRatio;
}

sealed class _PhotoEditAction {
  const factory _PhotoEditAction.crop(_PhotoCropPreset preset) =
      _CropPhotoEditAction;
  const factory _PhotoEditAction.reset() = _ResetPhotoEditAction;
}

class _CropPhotoEditAction implements _PhotoEditAction {
  const _CropPhotoEditAction(this.preset);

  final _PhotoCropPreset preset;
}

class _ResetPhotoEditAction implements _PhotoEditAction {
  const _ResetPhotoEditAction();
}

class _PendingPhotoTile extends StatelessWidget {
  const _PendingPhotoTile({
    required this.onEdit,
    required this.onRemove,
    required this.photo,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final _PendingHostPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Semantics(
              button: onEdit != null,
              label: 'Edit photo',
              child: SizedBox(
                width: 104,
                height: 92,
                child: InkWell(
                  onTap: onEdit,
                  child: Image.memory(
                    photo.candidate.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ready to upload',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${photo.candidate.width} x ${photo.candidate.height}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove photo',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoUploadPanel extends StatelessWidget {
  const _PhotoUploadPanel({
    required this.hasPhotos,
    required this.isBusy,
    required this.onTap,
    this.statusLabel,
  });

  final bool hasPhotos;
  final bool isBusy;
  final VoidCallback? onTap;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final borderColor = enabled
        ? const Color(0xFF9CA3AF)
        : const Color(0xFFD4D4D8);
    final iconColor = enabled
        ? const Color(0xFF52525B)
        : const Color(0xFFA1A1AA);
    final title = isBusy
        ? statusLabel ?? 'Working on photos'
        : hasPhotos
        ? 'Add another photo'
        : 'Upload parking photo';
    final subtitle = isBusy
        ? 'Please keep this screen open'
        : 'Camera or gallery';

    return Semantics(
      button: enabled,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: CustomPaint(
            painter: _DottedBorderPainter(color: borderColor),
            child: Container(
              constraints: const BoxConstraints(minHeight: 178),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isBusy)
                    const SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    )
                  else
                    Icon(
                      Icons.file_upload_outlined,
                      color: iconColor,
                      size: 42,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: enabled
                          ? const Color(0xFF0B0B0C)
                          : const Color(0xFF71717A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    const dashLength = 3.5;
    const gapLength = 6.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PhotosBottomAction extends StatelessWidget {
  const _PhotosBottomAction({
    required this.isBusy,
    required this.label,
    required this.onPressed,
  });

  final bool isBusy;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6F8),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B0B0C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isBusy
                  ? const Color(0xFF3F3F46)
                  : const Color(0xFFD4D4D8),
              disabledForegroundColor: isBusy
                  ? Colors.white
                  : const Color(0xFF71717A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}

class _PhotoCountPanel extends StatelessWidget {
  const _PhotoCountPanel({required this.count, required this.pendingCount});

  final int count;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final text = pendingCount > 0
        ? '$count of 5 uploaded. $pendingCount ready to upload.'
        : '$count of 5 photos added. Minimum 2 required.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.photo_library_outlined, color: Color(0xFF0B0B0C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF18181B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.canMoveDown,
    required this.canMoveUp,
    required this.deleting,
    required this.onDelete,
    required this.onMoveDown,
    required this.onMoveUp,
    required this.photo,
  });

  final bool canMoveDown;
  final bool canMoveUp;
  final bool deleting;
  final VoidCallback? onDelete;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveUp;
  final HostListingPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 92,
              child: Image.network(
                photo.secureUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFF3F4F6),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Parking photo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Move up',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            IconButton(
              tooltip: 'Delete photo',
              onPressed: deleting ? null : onDelete,
              icon: deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepEyebrow extends StatelessWidget {
  const _StepEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
