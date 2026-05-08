import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/fullscreen_image_viewer_page.dart';
import '../../../shared/widgets/state_view.dart';
import '../../parking/domain/parking_availability.dart';
import '../../parking/presentation/owner_parking_controller.dart';
import '../domain/user_setup_state.dart';
import 'user_setup_controller.dart';
import 'widgets/host_setup_app_bar.dart';

class HostSpaceReviewScreen extends ConsumerStatefulWidget {
  const HostSpaceReviewScreen({super.key});

  @override
  ConsumerState<HostSpaceReviewScreen> createState() =>
      _HostSpaceReviewScreenState();
}

class _HostSpaceReviewScreenState extends ConsumerState<HostSpaceReviewScreen> {
  bool _isEnsuringDraft = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDraft());
  }

  @override
  Widget build(BuildContext context) {
    final setupValue = ref.watch(userSetupControllerProvider);
    final draft = setupValue.value?.draft;

    if ((setupValue.isLoading || _isEnsuringDraft) && draft == null) {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _backToPhotos),
        child: const StateView(
          title: 'Preparing review',
          body: 'Loading your draft parking space.',
          isLoading: true,
        ),
      );
    }

    if (draft == null) {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _backToPhotos),
        child: StateView(
          title: 'Draft not ready',
          body: 'Start a host listing before submitting.',
          actionLabel: 'Start listing',
          onAction: () => _ensureDraft(),
        ),
      );
    }

    if (draft.status != 'draft') {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _backToPhotos),
        child: StateView(
          title: 'Listing submitted',
          body: 'Your parking space is pending review.',
          actionLabel: 'View my spaces',
          onAction: () => context.go('/profile/my-spaces'),
        ),
      );
    }

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: HostSetupAppBar(onBack: _backToPhotos),
      bottomNavigationBar: _ReviewBottomAction(
        isBusy: _isSubmitting,
        onPressed: _isSubmitting ? null : () => _submit(draft),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const _StepEyebrow('Step 4 of 4'),
          const SizedBox(height: 16),
          _ReviewSection(
            title: 'Basics',
            children: [
              _ReviewRow(label: 'Title', value: draft.title ?? 'Parking space'),
              _ReviewRow(
                label: 'Address',
                value: _textOrNotAdded(draft.address),
              ),
              _ReviewRow(label: 'City', value: _textOrNotAdded(draft.city)),
              _ReviewRow(
                label: 'State',
                value: _textOrNotAdded(draft.stateName),
              ),
              _ReviewRow(
                label: 'PIN code',
                value: _textOrNotAdded(draft.postalCode),
              ),
              _ReviewRow(
                label: 'Description',
                maxLines: 6,
                value: _descriptionLabel(draft),
              ),
              _ReviewRow(
                label: 'Vehicle fit',
                value: _labelFor(draft.vehicleFit),
              ),
              _ReviewRow(
                label: 'Parking type',
                value: _labelFor(draft.parkingType),
              ),
            ],
            onEdit: () => context.go('/setup/host-basics'),
          ),
          const SizedBox(height: 14),
          _ReviewSection(
            title: 'Pricing',
            children: [
              _ReviewRow(
                label: 'Hourly price',
                value: 'INR ${draft.hourlyPrice ?? 0}',
              ),
              _ReviewRow(label: 'Slots', value: draft.slotsCount.toString()),
              _ReviewRow(
                label: 'Available',
                maxLines: 4,
                value: _availabilityLabel(draft),
              ),
            ],
            onEdit: () => context.go('/setup/host-pricing'),
          ),
          const SizedBox(height: 14),
          _PhotoPreviewSection(
            photos: draft.photos,
            onEdit: () => context.go('/setup/host-photos'),
          ),
        ],
      ),
    );
  }

  void _backToPhotos() {
    context.go('/setup/host-photos');
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

  Future<void> _submit(HostListingDraft draft) async {
    if (!draft.hasBasics) {
      AppToast.error(context, 'Complete basics before submitting.');
      return;
    }
    if (!draft.hasPricing) {
      AppToast.error(context, 'Complete pricing before submitting.');
      return;
    }
    if (draft.photos.length < 2) {
      AppToast.error(context, 'Add at least two photos.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(userSetupControllerProvider.notifier).submitHostListing();
      if (mounted) {
        ref.invalidate(ownedParkingSpacesProvider);
        AppToast.success(context, 'Listing submitted for review');
        context.go('/profile/my-spaces');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _availabilityLabel(HostListingDraft draft) {
    final fromDate = draft.availableFromDate;
    final toDate = draft.availableToDate;
    final start = draft.dailyStartMinute;
    final end = draft.dailyEndMinute;
    if (fromDate == null || toDate == null || start == null || end == null) {
      return 'Not added';
    }
    final range = '${_dateLabel(fromDate)} to ${_dateLabel(toDate)}';
    final time = '${parkingMinuteLabel(start)} - ${parkingMinuteLabel(end)}';
    final weekend = draft.skipWeekends ? ', weekdays only' : '';
    return '$range, $time$weekend';
  }

  String _descriptionLabel(HostListingDraft draft) {
    final text = draft.accessInstructions?.trim();
    return text == null || text.isEmpty ? 'Not added' : text;
  }

  String _textOrNotAdded(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? 'Not added' : text;
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _labelFor(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return 'Not added';
    return text
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.children,
    required this.onEdit,
    required this.title,
  });

  final List<Widget> children;
  final VoidCallback onEdit;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit $title',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(38, 38),
                    foregroundColor: const Color(0xFF18181B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFEDEEF1)),
                )
              else
                const SizedBox(height: 10),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.maxLines = 3,
  });

  final String label;
  final int maxLines;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 106,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0B0B0C),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPreviewSection extends StatelessWidget {
  const _PhotoPreviewSection({required this.onEdit, required this.photos});

  final VoidCallback onEdit;
  final List<HostListingPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos (${photos.length})',
                    style: const TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit photos',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(38, 38),
                    foregroundColor: const Color(0xFF18181B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (photos.isEmpty)
              const SizedBox(
                height: 96,
                child: Center(
                  child: Text(
                    'No photos added',
                    style: TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            else
              RepaintBoundary(
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 4),
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return Semantics(
                        button: true,
                        label: 'View parking photo ${index + 1}',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openPhotoViewer(context, index),
                            child: SizedBox(
                              width: 112,
                              height: 96,
                              child: CachedNetworkImage(
                                imageUrl: photo.secureUrl,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                memCacheHeight:
                                    (96 *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round(),
                                memCacheWidth:
                                    (112 *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .round(),
                                placeholder: (_, _) => const ColoredBox(
                                  color: Color(0xFFF3F4F6),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.1,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFF3F4F6),
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemCount: photos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhotoViewer(BuildContext context, int initialIndex) {
    final imageUrls = <String>[];
    for (final photo in photos) {
      final url = photo.secureUrl.trim();
      if (url.isNotEmpty) imageUrls.add(url);
    }
    if (imageUrls.isEmpty) return Future<void>.value();
    return showFullscreenImageViewer(
      context,
      imageUrls: imageUrls,
      initialIndex: initialIndex.clamp(0, imageUrls.length - 1).toInt(),
    );
  }
}

class _ReviewBottomAction extends StatelessWidget {
  const _ReviewBottomAction({required this.isBusy, required this.onPressed});

  final bool isBusy;
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
              disabledBackgroundColor: const Color(0xFF3F3F46),
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
                : const Text('Submit for review'),
          ),
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
