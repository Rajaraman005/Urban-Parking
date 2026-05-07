import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../../parking/domain/parking_availability.dart';
import '../../parking/presentation/widgets/listing_availability_editor.dart';
import '../domain/user_setup_state.dart';
import 'user_setup_controller.dart';
import 'widgets/host_setup_app_bar.dart';

class HostSpacePricingScreen extends ConsumerStatefulWidget {
  const HostSpacePricingScreen({super.key});

  @override
  ConsumerState<HostSpacePricingScreen> createState() =>
      _HostSpacePricingScreenState();
}

class _HostSpacePricingScreenState
    extends ConsumerState<HostSpacePricingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController(text: '50');
  final _slotsController = TextEditingController(text: '1');

  late ListingAvailabilityValue _availability;
  String? _seededDraftId;
  int? _seededVersion;
  bool _isEnsuringDraft = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final today = parkingDateOnly(DateTime.now());
    _availability = ListingAvailabilityValue(
      dailyEndMinute: 20 * 60,
      dailyStartMinute: 8 * 60,
      fromDate: today,
      skipWeekends: false,
      toDate: today.add(const Duration(days: 30)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDraft());
  }

  @override
  void dispose() {
    _priceController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupValue = ref.watch(userSetupControllerProvider);
    final draft = setupValue.value?.draft;
    if (draft != null) _seed(draft);

    if ((setupValue.isLoading || _isEnsuringDraft) && draft == null) {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _backToBasics),
        child: const StateView(
          title: 'Preparing pricing',
          body: 'Loading your draft parking space.',
          isLoading: true,
        ),
      );
    }

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: HostSetupAppBar(onBack: _backToBasics),
      bottomNavigationBar: _PricingBottomAction(
        isSaving: _isSaving,
        onPressed: _isSaving ? null : _savePricing,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _SetupHeader(eyebrow: 'Step 2 of 4'),
            const SizedBox(height: 12),
            _FormSection(
              title: 'Price',
              child: Column(
                children: [
                  _PricingNumberField(
                    controller: _priceController,
                    helper: 'INR per hour',
                    label: 'Hourly price',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    keyboardType: TextInputType.number,
                    prefixText: '\u20B9',
                    suffixText: '/ hr',
                    validator: (value) {
                      final price = int.tryParse(value?.trim() ?? '');
                      if (price == null || price < 10 || price > 10000) {
                        return 'Enter INR 10 to INR 10,000.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _PricingNumberField(
                    controller: _slotsController,
                    helper: 'Available bays',
                    label: 'Number of slots',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    keyboardType: TextInputType.number,
                    suffixText: 'slots',
                    validator: (value) {
                      final slots = int.tryParse(value?.trim() ?? '');
                      if (slots == null || slots < 1 || slots > 50) {
                        return 'Enter 1 to 50 slots.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Availability',
              child: ListingAvailabilityEditor(
                enabled: !_isSaving,
                value: _availability,
                onChanged: (value) => setState(() => _availability = value),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _backToBasics() {
    context.go('/setup/host-basics');
  }

  void _seed(HostListingDraft draft) {
    if (_seededDraftId == draft.id && _seededVersion == draft.version) return;
    _seededDraftId = draft.id;
    _seededVersion = draft.version;
    _priceController.text = (draft.hourlyPrice ?? 50).toString();
    _slotsController.text = draft.slotsCount.toString();
    final today = parkingDateOnly(DateTime.now());
    _availability = ListingAvailabilityValue(
      dailyEndMinute: draft.dailyEndMinute ?? 20 * 60,
      dailyStartMinute: draft.dailyStartMinute ?? 8 * 60,
      fromDate: draft.availableFromDate ?? today,
      skipWeekends: draft.skipWeekends,
      toDate: draft.availableToDate ?? today.add(const Duration(days: 30)),
    );
  }

  Future<void> _savePricing() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final fromDate = _availability.fromDate;
    final toDate = _availability.toDate;
    if (fromDate == null || toDate == null) {
      AppToast.error(context, 'Choose available dates.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .saveHostPricing(
            HostPricingDraftUpdate(
              availableFromDate: fromDate,
              availableToDate: toDate,
              dailyEndMinute: _availability.dailyEndMinute,
              dailyStartMinute: _availability.dailyStartMinute,
              hourlyPrice: int.parse(_priceController.text.trim()),
              skipWeekends: _availability.skipWeekends,
              slotsCount: int.parse(_slotsController.text.trim()),
            ),
          );
      if (mounted) context.go('/setup/host-photos');
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }
}

class _PricingBottomAction extends StatelessWidget {
  const _PricingBottomAction({required this.isSaving, required this.onPressed});

  final bool isSaving;
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
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text('Save pricing'),
          ),
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.eyebrow});

  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Text(
      eyebrow,
      style: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _PricingNumberField extends StatelessWidget {
  const _PricingNumberField({
    required this.controller,
    required this.helper,
    required this.label,
    required this.validator,
    this.inputFormatters = const [],
    this.keyboardType,
    this.prefixText,
    this.suffixText,
  });

  final TextEditingController controller;
  final String helper;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType? keyboardType;
  final String label;
  final String? prefixText;
  final String? suffixText;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF18181B),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: _pricingInputDecoration(
            prefixText: prefixText,
            suffixText: suffixText,
          ),
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.15,
            letterSpacing: 0,
          ),
          textInputAction: TextInputAction.next,
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _pricingInputDecoration({
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      prefixText: prefixText == null ? null : '$prefixText ',
      prefixStyle: const TextStyle(
        color: Color(0xFF52525B),
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.15,
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.child, required this.title});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0B0B0C),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
