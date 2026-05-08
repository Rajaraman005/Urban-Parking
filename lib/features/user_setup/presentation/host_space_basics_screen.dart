import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/widgets/address_search_map_picker.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../../parking/domain/owner_parking_repository.dart';
import '../domain/user_setup_state.dart';
import 'host_setup_launcher.dart';
import 'host_setup_launch_controller.dart';
import 'user_setup_controller.dart';
import 'widgets/host_setup_app_bar.dart';

class HostSpaceBasicsScreen extends ConsumerStatefulWidget {
  const HostSpaceBasicsScreen({
    super.key,
    this.createNew = false,
    this.instantLaunch = false,
  });

  final bool createNew;
  final bool instantLaunch;

  @override
  ConsumerState<HostSpaceBasicsScreen> createState() =>
      _HostSpaceBasicsScreenState();
}

class _HostSpaceBasicsScreenState extends ConsumerState<HostSpaceBasicsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();
  final _localityController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _instructionsController = TextEditingController();

  List<ParkingAddressCandidate> _addressResults = const [];
  Map<String, Object?>? _addressRaw;
  String? _addressPlaceId;
  String _addressProvider = 'manual';
  double _addressConfidence = 0.85;
  GeoPoint? _selectedLocation;
  String _parkingType = 'open';
  String _vehicleFit = 'car';
  String? _seededDraftId;
  int? _seededVersion;
  Timer? _addressSearchDebounce;
  int _addressSearchToken = 0;
  bool _freshDraftReady = false;
  bool _requestedDraft = false;
  bool _isEnsuringDraft = false;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.instantLaunch) {
        ref.read(hostSetupLaunchControllerProvider.notifier).markFirstFrame();
        return;
      }
      _ensureDraft();
    });
  }

  @override
  void dispose() {
    _addressSearchDebounce?.cancel();
    _addressController.dispose();
    _cityController.dispose();
    _instructionsController.dispose();
    _localityController.dispose();
    _postalCodeController.dispose();
    _searchController.dispose();
    _stateController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HostSetupLaunchState>(hostSetupLaunchControllerProvider, (
      previous,
      next,
    ) {
      if (!widget.instantLaunch || !mounted) return;
      if (next.phase == HostSetupLaunchPhase.failed &&
          previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        AppToast.error(context, next.errorMessage!);
      }
      if (next.shouldAutoRoute &&
          next.activeStep != null &&
          next.activeStep != 'host_basics') {
        ref.read(hostSetupLaunchControllerProvider.notifier).clearAutoRoute();
        context.go(routeForHostSetupStep(next.activeStep));
      }
    });

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final launchState = ref.watch(hostSetupLaunchControllerProvider);
    final shouldReadSetupDraft =
        !widget.instantLaunch ||
        launchState.phase == HostSetupLaunchPhase.draftReady;
    final setupValue = shouldReadSetupDraft
        ? ref.watch(userSetupControllerProvider)
        : null;
    final setupState = setupValue?.value;
    final draft =
        !shouldReadSetupDraft ||
            (widget.createNew && !_freshDraftReady && !widget.instantLaunch)
        ? null
        : setupState?.draft;
    if (draft != null && _shouldSeed(draft)) _seed(draft);
    final isLaunchPreparing =
        widget.instantLaunch && launchState.shouldBlockInitialSave;

    if (!widget.instantLaunch &&
        !widget.createNew &&
        ((setupValue?.isLoading ?? false) || _isEnsuringDraft) &&
        draft == null) {
      return AppScreen(
        padded: false,
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: HostSetupAppBar(onBack: _closeSetup),
        child: const StateView(
          title: 'Preparing listing',
          body: 'Creating your draft parking space.',
          isLoading: true,
        ),
      );
    }

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: HostSetupAppBar(onBack: _closeSetup),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + bottomPadding),
          children: [
            const _SetupHeader(
              eyebrow: 'Step 1 of 4',
              body:
                  'Add the address and basic details renters need before booking.',
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Listing',
              child: TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Listing title'),
                style: _fieldTextStyle,
                textInputAction: TextInputAction.next,
                validator: _requiredText(
                  minLength: 3,
                  message: 'Enter a clear listing title.',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Address',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AddressSearchMapPicker<ParkingAddressCandidate>(
                    deferMapPreview: widget.instantLaunch,
                    enabled: !_isSaving,
                    fallbackLocation: AppConstants.chennaiCenter,
                    isLocating: _isLocating,
                    isSearching: _isSearching,
                    location: _selectedLocation,
                    onClearSearch: _clearSearch,
                    onLocationChanged: _applyMapLocation,
                    onSearch: _searchAddress,
                    onSearchChanged: _handleSearchQueryChanged,
                    onSuggestionSelected: _selectAddress,
                    onUseCurrentLocation: _useCurrentLocation,
                    searchController: _searchController,
                    searchLabel: 'Search street, building, or landmark',
                    suggestionTitleBuilder: (candidate) => candidate.address,
                    suggestions: _addressResults,
                  ),
                  const SizedBox(height: 14),
                  const _FieldCaption('Full address'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _addressController,
                    decoration: _addressInputDecoration(
                      'Street, building, landmark',
                    ),
                    style: _fieldTextStyle,
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => _markAddressEdited(),
                    textCapitalization: TextCapitalization.words,
                    validator: _requiredText(
                      minLength: 8,
                      message: 'Enter the full parking address.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FieldCaption('City'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _cityController,
                              decoration: _addressInputDecoration('City name'),
                              style: _fieldTextStyle,
                              onChanged: (_) => _markAddressEdited(),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: _requiredText(
                                minLength: 2,
                                message: 'Enter city.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FieldCaption('State'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _stateController,
                              decoration: _addressInputDecoration('State name'),
                              style: _fieldTextStyle,
                              onChanged: (_) => _markAddressEdited(),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: _requiredText(
                                minLength: 2,
                                message: 'Enter state.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _FieldCaption('PIN code'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: _addressInputDecoration('6 digit PIN'),
                    style: _fieldTextStyle,
                    onChanged: (_) => _markAddressEdited(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(text)) {
                        return 'Enter a valid 6 digit PIN code.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const _FieldCaption('Coordinates'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: ValueKey(_coordinatesText),
                    initialValue: _coordinatesText,
                    canRequestFocus: false,
                    decoration: _addressInputDecoration(
                      'Map pin coordinates',
                      readOnly: true,
                    ),
                    readOnly: true,
                    style: _coordinateTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Parking details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Vehicle fit'),
                  _ChoiceWrap(
                    value: _vehicleFit,
                    options: const [
                      _ChoiceOption('bike', 'Bike', Icons.two_wheeler_rounded),
                      _ChoiceOption('car', 'Car', Icons.directions_car_rounded),
                      _ChoiceOption('both', 'Both', Icons.garage_rounded),
                    ],
                    onChanged: (value) => setState(() => _vehicleFit = value),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Parking type'),
                  _ChoiceWrap(
                    value: _parkingType,
                    options: const [
                      _ChoiceOption('open', 'Open', Icons.local_parking),
                      _ChoiceOption('covered', 'Covered', Icons.roofing),
                      _ChoiceOption('basement', 'Basement', Icons.apartment),
                      _ChoiceOption('garage', 'Garage', Icons.garage_rounded),
                      _ChoiceOption('driveway', 'Driveway', Icons.home_work),
                    ],
                    onChanged: (value) => setState(() => _parkingType = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('host-space-description-field'),
                    controller: _instructionsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    // decoration: _inputDecoration(
                    //   'Description',
                    // ).copyWith(helperText: '50-200 characters'),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_descriptionMaxLength),
                    ],
                    keyboardType: TextInputType.multiline,
                    maxLength: _descriptionMaxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    style: _fieldTextStyle,
                    maxLines: 4,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    validator: _descriptionValidator,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed:
                    _isSaving ||
                        _isEnsuringDraft ||
                        isLaunchPreparing ||
                        (widget.createNew &&
                            !_freshDraftReady &&
                            !widget.instantLaunch)
                    ? null
                    : _saveBasics,
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
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        _isEnsuringDraft ||
                                isLaunchPreparing ||
                                (widget.createNew &&
                                    !_freshDraftReady &&
                                    !widget.instantLaunch)
                            ? 'Preparing draft'
                            : 'Save basics',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF52525B),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
    );
  }

  InputDecoration _addressInputDecoration(
    String hint, {
    bool readOnly = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: readOnly ? const Color(0xFFF3F4F6) : const Color(0xFFF8F8FA),
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  TextStyle get _fieldTextStyle => const TextStyle(
    color: Color(0xFF18181B),
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 0,
  );

  TextStyle get _coordinateTextStyle => const TextStyle(
    color: Color(0xFF374151),
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: 0,
  );

  FormFieldValidator<String> _requiredText({
    required int minLength,
    required String message,
  }) {
    return (value) {
      final text = value?.trim() ?? '';
      return text.length < minLength ? message : null;
    };
  }

  String? _descriptionValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < _descriptionMinLength) {
      return 'Description must be at least 50 characters.';
    }
    if (text.length > _descriptionMaxLength) {
      return 'Description must be 200 characters or fewer.';
    }
    return null;
  }

  void _handleSearchQueryChanged(String value) {
    _addressSearchDebounce?.cancel();
    _addressSearchToken += 1;
    if (_addressResults.isNotEmpty || _isSearching) {
      setState(() {
        _addressResults = const [];
        _isSearching = false;
      });
    }

    final query = value.trim();
    if (query.length < _addressAutocompleteMinLength) {
      return;
    }

    final token = _addressSearchToken;
    _addressSearchDebounce = Timer(_addressAutocompleteDelay, () {
      unawaited(
        _searchAddress(query: query, isAutocomplete: true, token: token),
      );
    });
  }

  Future<void> _searchAddress({
    String? query,
    bool isAutocomplete = false,
    int? token,
  }) async {
    if (!isAutocomplete) _addressSearchDebounce?.cancel();
    final searchToken = token ?? ++_addressSearchToken;
    final effectiveQuery = (query ?? _searchController.text).trim();
    if (effectiveQuery.length < _addressAutocompleteMinLength) {
      if (!isAutocomplete) {
        AppToast.error(context, 'Enter a more specific address.');
      }
      return;
    }

    if (!isAutocomplete) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSearching = true);
    try {
      final results = await ref
          .read(userSetupControllerProvider.notifier)
          .searchAddress(effectiveQuery);
      if (!mounted || searchToken != _addressSearchToken) return;
      setState(() => _addressResults = results);
      if (!isAutocomplete && results.isEmpty) {
        AppToast.info(context, 'No address matches found.');
      }
    } catch (error) {
      if (!mounted || searchToken != _addressSearchToken) return;
      if (isAutocomplete) {
        setState(() => _addressResults = const []);
      } else {
        AppToast.error(context, _errorMessage(error));
      }
    } finally {
      if (mounted && searchToken == _addressSearchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectAddress(ParkingAddressCandidate candidate) {
    _cancelAddressAutocomplete();
    setState(() {
      _addressController.text = candidate.address;
      _cityController.text =
          candidate.city ?? candidate.locality ?? _cityController.text;
      _localityController.text =
          candidate.locality ?? candidate.city ?? _cityController.text;
      _stateController.text =
          _stateFromCandidate(candidate) ?? _stateController.text;
      _postalCodeController.text =
          candidate.postalCode ?? _postalCodeController.text;
      _addressConfidence = candidate.confidence;
      _addressPlaceId = candidate.placeId;
      _addressProvider = candidate.provider;
      _addressRaw = candidate.raw;
      _selectedLocation = GeoPoint(
        latitude: candidate.latitude,
        longitude: candidate.longitude,
      );
      _addressResults = const [];
    });
  }

  void _applyMapLocation(GeoPoint location) {
    _cancelAddressAutocomplete();
    setState(() {
      _selectedLocation = location;
      _addressConfidence = 0.85;
      _addressPlaceId = null;
      _addressProvider = 'manual';
      _addressRaw = null;
      _addressResults = const [];
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    _cancelAddressAutocomplete();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLocating = true);
    try {
      final result = await ref.read(locationServiceProvider).currentLocation();
      final location = result.location;
      if (location == null) {
        if (mounted) {
          AppToast.error(context, result.error ?? 'Location unavailable.');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _searchController.clear();
        _clearAddressFields();
        _addressConfidence = result.isFallback ? 0.5 : 0.9;
        _addressPlaceId = null;
        _addressProvider = 'manual';
        _addressRaw = null;
        _addressResults = const [];
        _selectedLocation = location;
      });
      AppToast.success(
        context,
        result.error ?? 'Map moved to your current location.',
      );
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveBasics() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final location = _selectedLocation;
    if (location == null) {
      AppToast.error(
        context,
        'Select an address result to confirm the map pin.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .saveHostBasics(
            HostBasicsDraftUpdate(
              accessInstructions: _instructionsController.text.trim(),
              address: _addressController.text,
              addressConfidence: _addressConfidence,
              addressPlaceId: _addressPlaceId,
              addressProvider: _addressProvider,
              addressRaw: _addressRawForSave(),
              city: _cityController.text,
              locality: _localityForSave,
              location: location,
              parkingType: _parkingType,
              postalCode: _postalCodeController.text,
              stateName: _stateController.text,
              title: _titleController.text,
              vehicleFit: _vehicleFit,
            ),
          );
      if (mounted) context.go('/setup/host-pricing');
    } catch (error) {
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _ensureDraft() async {
    if (_isEnsuringDraft || _requestedDraft) return;
    if (widget.instantLaunch) return;
    final setup = ref.read(userSetupControllerProvider).value;
    if (!widget.createNew && setup?.draft != null) return;
    _requestedDraft = true;
    setState(() => _isEnsuringDraft = true);
    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .startHostListing(createNew: widget.createNew);
      if (mounted && widget.createNew) {
        setState(() => _freshDraftReady = true);
      }
    } catch (error) {
      _requestedDraft = false;
      if (mounted) AppToast.error(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isEnsuringDraft = false);
    }
  }

  void _seed(HostListingDraft draft) {
    if (_seededDraftId == draft.id && _seededVersion == draft.version) return;
    _seededDraftId = draft.id;
    _seededVersion = draft.version;
    _titleController.text = draft.title ?? '';
    _addressController.text = draft.address ?? '';
    _localityController.text = draft.locality ?? '';
    _cityController.text = draft.city ?? '';
    _stateController.text =
        draft.stateName ?? _stateFromRaw(draft.addressRaw) ?? '';
    _postalCodeController.text = draft.postalCode ?? '';
    _instructionsController.text = draft.accessInstructions ?? '';
    _parkingType = draft.parkingType ?? _parkingType;
    _vehicleFit = draft.vehicleFit ?? _vehicleFit;
    _addressConfidence = draft.addressConfidence ?? _addressConfidence;
    _addressPlaceId = draft.addressPlaceId;
    _addressProvider = draft.addressProvider ?? _addressProvider;
    _addressRaw = draft.addressRaw;
    _selectedLocation = draft.location;
  }

  bool _shouldSeed(HostListingDraft draft) {
    if (!widget.createNew) return true;
    if (_seededDraftId != null) return true;
    return draft.hasBasics;
  }

  void _closeSetup() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/profile');
  }

  void _markAddressEdited() {
    if (_addressProvider == 'manual' &&
        _addressPlaceId == null &&
        _addressRaw == null) {
      return;
    }
    setState(() {
      _addressConfidence = _selectedLocation == null ? 0.85 : 0.8;
      _addressPlaceId = null;
      _addressProvider = 'manual';
      _addressRaw = null;
    });
  }

  void _clearSearch() {
    _cancelAddressAutocomplete();
    setState(() {
      _searchController.clear();
      _addressResults = const [];
      _isSearching = false;
    });
  }

  void _cancelAddressAutocomplete() {
    _addressSearchDebounce?.cancel();
    _addressSearchToken += 1;
  }

  void _clearAddressFields() {
    _addressController.clear();
    _localityController.clear();
    _cityController.clear();
    _stateController.clear();
    _postalCodeController.clear();
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }

  String get _coordinatesText {
    final location = _selectedLocation;
    if (location == null) return '';
    return '${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}';
  }

  String get _localityForSave {
    final locality = _localityController.text.trim();
    if (locality.isNotEmpty) return locality;
    return _cityController.text.trim();
  }

  Map<String, Object?>? _addressRawForSave() {
    final state = _stateController.text.trim();
    if (state.isEmpty) return _addressRaw;

    final raw = _addressRaw == null
        ? <String, Object?>{}
        : Map<String, Object?>.from(_addressRaw!);
    raw['state'] = state;

    final address = raw['address'];
    if (address is Map) {
      raw['address'] = {...Map<String, Object?>.from(address), 'state': state};
    } else {
      raw['address'] = {'state': state};
    }
    return raw;
  }

  String? _stateFromCandidate(ParkingAddressCandidate candidate) {
    final state = candidate.state?.trim();
    if (state != null && state.isNotEmpty) return state;
    return _stateFromRaw(candidate.raw);
  }

  String? _stateFromRaw(Map<String, Object?>? raw) {
    return _firstNestedString(raw, const [
      ['address', 'state'],
      ['address', 'region'],
      ['address', 'state_district'],
      ['state'],
      ['region'],
    ]);
  }

  String? _firstNestedString(
    Map<String, Object?>? raw,
    List<List<String>> paths,
  ) {
    if (raw == null) return null;
    for (final path in paths) {
      Object? cursor = raw;
      for (final segment in path) {
        if (cursor is! Map) {
          cursor = null;
          break;
        }
        cursor = cursor[segment];
      }
      final value = cursor?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

const _addressAutocompleteDelay = Duration(milliseconds: 350);
const _addressAutocompleteMinLength = 4;
const _descriptionMaxLength = 200;
const _descriptionMinLength = 50;

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({required this.body, required this.eyebrow});

  final String body;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(
            color: Color(0xFF52525B),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: 0,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0B0B0C),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
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

class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF18181B),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption(this.value, this.label, this.icon);

  final IconData icon;
  final String label;
  final String value;
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.onChanged,
    required this.options,
    required this.value,
  });

  final ValueChanged<String> onChanged;
  final List<_ChoiceOption> options;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _ChoiceChipButton(
            icon: option.icon,
            label: option.label,
            selected: option.value == value,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFF8F8FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF18181B),
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF18181B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
