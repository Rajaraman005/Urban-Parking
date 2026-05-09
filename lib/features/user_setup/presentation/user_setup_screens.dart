import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/media/photo_crop/photo_crop.dart';
import '../../../shared/validation/indian_mobile_number.dart';
import '../../../shared/validation/indian_vehicle_registration.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/domain/profile_repository.dart';
import '../../profile/presentation/profile_details_controller.dart';
import '../../profile/presentation/profile_display.dart';
import 'user_setup_controller.dart';

export 'host_space_basics_screen.dart';
export 'host_space_photos_screen.dart';
export 'host_space_pricing_screen.dart';
export 'host_space_review_screen.dart';

class UserSetupIntentScreen extends ConsumerWidget {
  const UserSetupIntentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      appBar: AppBar(
        title: const Text('Setup'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How will you use Lotzi?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(userSetupControllerProvider.notifier)
                  .saveIntent('park');
              if (context.mounted) context.go('/setup/profile');
            },
            icon: const Icon(Icons.local_parking_outlined),
            label: const Text('Find parking'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await ref
                  .read(userSetupControllerProvider.notifier)
                  .saveIntent('host');
              if (context.mounted) context.go('/setup/profile');
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Host a space'),
          ),
        ],
      ),
    );
  }
}

class UserSetupProfileScreen extends ConsumerStatefulWidget {
  const UserSetupProfileScreen({super.key});

  @override
  ConsumerState<UserSetupProfileScreen> createState() =>
      _UserSetupProfileScreenState();
}

class _UserSetupProfileScreenState
    extends ConsumerState<UserSetupProfileScreen> {
  static final DateTime _defaultDobPickerDate = DateTime(1999, 10, 14);
  static const _backgroundColor = Colors.white;
  static const _surfaceColor = Color(0xFFF7F7F8);
  static const _borderColor = Color(0xFFE4E4E7);
  static const _inkColor = Color(0xFF0B0B0C);
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _backgroundColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: _backgroundColor,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const _genderOptions = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('other', 'Other'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  DateTime? _dob;
  String? _gender;
  bool _avatarUploading = false;
  bool _didSeed = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).value;
    _seedFromAuth(authState);
    final setupState = ref.watch(userSetupControllerProvider).value;
    final authProfile = authState?.profile;
    final avatarUrl = displayProfileAvatarUrl(authProfile);
    final intent = setupState?.intent ?? authProfile?.intent;
    final isHostIntent = intent == 'host';
    final continueLabel = isHostIntent ? 'Continue to hosting' : 'Continue';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        backgroundColor: _backgroundColor,
        safeAreaBackgroundColor: _backgroundColor,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: _SetupBottomAction(
          label: continueLabel,
          loading: _saving,
          onPressed: _saving ? null : () => _submit(intent),
        ),
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _saving ? null : _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Personal details',
            style: TextStyle(
              color: _inkColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          bottom: const _SetupProgressAppBarBottom(progress: 0.5),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(0, 34, 0, 116),
            children: [
              Center(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _fullNameController,
                  builder: (context, value, _) {
                    return _SetupProfileAvatar(
                      avatarUrl: avatarUrl,
                      fullName: value.text,
                      loading: _avatarUploading,
                      onTap: _saving || _avatarUploading
                          ? null
                          : _pickAndUploadAvatar,
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              _FieldLabel(label: 'Full name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameController,
                enabled: !_saving,
                onTapOutside: (_) => _clearTextInputFocus(),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _inputDecoration('Your full name'),
                validator: _validateFullName,
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: 'Mobile number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                onFieldSubmitted: (_) => _clearTextInputFocus(),
                onTapOutside: (_) => _clearTextInputFocus(),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [_IndianMobileNumberInputFormatter()],
                decoration: _inputDecoration(
                  '10 digit mobile number',
                  prefix: const _PhoneCountryPrefix(),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: 'Gender'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < _genderOptions.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _SetupOptionChip(
                        label: _genderOptions[index].$2,
                        selected: _gender == _genderOptions[index].$1,
                        onTap: _saving
                            ? null
                            : () {
                                _clearTextInputFocus();
                                setState(() {
                                  _gender = _genderOptions[index].$1;
                                  _errorMessage = null;
                                });
                              },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: 'Date of birth'),
              const SizedBox(height: 8),
              _SetupDatePickerTile(
                value: _dob,
                onTap: _saving ? null : _pickDob,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _SetupErrorBanner(message: _errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _seedFromAuth(AuthState? auth) {
    if (_didSeed) return;
    final profile = auth?.profile;
    if (profile == null) return;

    _didSeed = true;
    final fullName = profile.fullName?.trim();
    _fullNameController.text = fullName == null || fullName.isEmpty
        ? ''
        : fullName;
    _phoneController.text = _normalizePhone(profile.phone) ?? '';
    _gender = _isVisibleGenderOption(profile.gender) ? profile.gender : null;
    _dob = profile.dob;
  }

  bool _isVisibleGenderOption(String? value) {
    if (value == null || value.isEmpty) return false;
    return _genderOptions.any((option) => option.$1 == value);
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefix}) {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceColor,
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _inkColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.4),
      ),
    );
  }

  String? _validateFullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) {
      return 'Enter your full name';
    }
    if (text.length > 80) {
      return 'Name is too long';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final issue = IndianMobileNumber.issue(value);
    if (issue != null) return IndianMobileNumber.message(issue);
    return null;
  }

  String? _normalizePhone(String? value) {
    return IndianMobileNumber.normalize(value);
  }

  void _clearTextInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  }

  Future<void> _pickDob() async {
    _clearTextInputFocus();
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 100, now.month, now.day);
    final initialDate = _clampDate(
      _dob ?? _defaultDobPickerDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    DateTime? picked;
    try {
      picked = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        requestFocus: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.48),
        builder: (context) => _DobPickerSheet(
          firstDate: firstDate,
          initialDate: initialDate,
          lastDate: lastDate,
        ),
      );
    } finally {
      _clearTextInputFocus();
    }
    final selectedDate = picked;
    if (selectedDate == null || !mounted) return;
    setState(() {
      _dob = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      _errorMessage = null;
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxHeight: 1800,
        maxWidth: 1800,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _avatarUploading = true;
        _errorMessage = null;
      });

      final config = PhotoCropConfig.avatar();
      final source = await PhotoCropEngine.sourceFromXFile(
        picked,
        config: config,
        fallbackFileName: 'profile-photo.jpg',
        pickerMaxDimension: 1800,
      );
      if (!mounted) return;

      setState(() => _avatarUploading = false);
      final cropped = await openPhotoCropEditor(
        context: context,
        config: config,
        source: source,
      );
      if (cropped == null || !mounted) {
        return;
      }

      setState(() => _avatarUploading = true);
      final image = ProfileAvatarUploadCandidate(
        bytes: cropped.bytes,
        fileName: cropped.fileName,
        height: cropped.height,
        mimeType: cropped.mimeType,
        width: cropped.width,
      );

      await ref
          .read(profileDetailsControllerProvider.notifier)
          .updateAvatar(image);
      if (!mounted) return;
      setState(() => _errorMessage = null);
    } catch (error) {
      if (!mounted) return;
      _setError(_errorText(error));
    } finally {
      if (mounted) {
        setState(() => _avatarUploading = false);
      }
    }
  }

  DateTime _clampDate(
    DateTime value, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final date = DateTime(value.year, value.month, value.day);
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;
    return date;
  }

  Future<void> _submit(String? intent) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    final dob = _dob;
    final gender = _gender;

    if (intent != 'park' && intent != 'host') {
      _setError('Choose how you want to use Lotzi first.');
      return;
    }
    if (gender == null || gender.isEmpty) {
      _setError('Choose a gender option.');
      return;
    }
    if (dob == null) {
      _setError('Choose your date of birth.');
      return;
    }
    if (!isValid) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final next = await ref
          .read(userSetupControllerProvider.notifier)
          .saveProfile(
            fullName: _fullNameController.text,
            phone: _normalizePhone(_phoneController.text) ?? '',
            gender: gender,
            dob: _dateLabel(dob),
          );
      if (!mounted) return;
      if (next.step == 'host_basics') {
        context.go('/setup/host-basics');
      } else if (next.step == 'vehicle_details') {
        context.go('/setup/vehicle');
      } else {
        context.go('/search');
      }
    } catch (error) {
      if (!mounted) return;
      _setError(_errorText(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
  }

  String _errorText(Object error) {
    if (error is PhotoCropException) {
      return error.message;
    }
    if (error is AppFailure) {
      return error.message;
    }
    return 'Could not save your details. Please try again.';
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  void _goBack() {
    context.go('/setup/intent');
  }
}

class UserSetupVehicleScreen extends ConsumerStatefulWidget {
  const UserSetupVehicleScreen({super.key});

  @override
  ConsumerState<UserSetupVehicleScreen> createState() =>
      _UserSetupVehicleScreenState();
}

class _UserSetupVehicleScreenState
    extends ConsumerState<UserSetupVehicleScreen> {
  static const _backgroundColor = Colors.white;
  static const _surfaceColor = Color(0xFFF7F7F8);
  static const _borderColor = Color(0xFFE4E4E7);
  static const _inkColor = Color(0xFF0B0B0C);
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _backgroundColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: _backgroundColor,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _registrationController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  bool _didSeed = false;
  bool _saving = false;
  String? _errorMessage;
  String? _vehicleType;

  @override
  void initState() {
    super.initState();
    _registrationController = TextEditingController();
    _makeController = TextEditingController();
    _modelController = TextEditingController();
  }

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).value;
    _seedFromAuth(authState);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        backgroundColor: _backgroundColor,
        safeAreaBackgroundColor: _backgroundColor,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: _SetupBottomAction(
          label: 'Start finding parking',
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _saving ? null : () => context.go('/setup/profile'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Vehicle details',
            style: TextStyle(
              color: _inkColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          bottom: const _SetupProgressAppBarBottom(progress: 1),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 116),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Align(
                    alignment: const Alignment(0, -0.18),
                    child: _VehicleDetailsFormContent(
                      errorMessage: _errorMessage,
                      inputDecoration: _inputDecoration,
                      makeController: _makeController,
                      modelController: _modelController,
                      normalizeFocus: _clearTextInputFocus,
                      onSelectVehicleType: _saving ? null : _selectVehicleType,
                      registrationController: _registrationController,
                      saving: _saving,
                      validateOptionalVehicleText: _validateOptionalVehicleText,
                      validateRegistration: _validateRegistration,
                      vehicleType: _vehicleType,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _seedFromAuth(AuthState? auth) {
    if (_didSeed) return;
    final profile = auth?.profile;
    if (profile == null) return;

    _didSeed = true;
    _vehicleType = _isVehicleType(profile.vehicleType)
        ? profile.vehicleType
        : null;
    _registrationController.text = profile.vehicleRegistration ?? '';
    _makeController.text = profile.vehicleMake ?? '';
    _modelController.text = profile.vehicleModel ?? '';
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: _surfaceColor,
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _inkColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.4),
      ),
    );
  }

  void _selectVehicleType(String value) {
    _clearTextInputFocus();
    setState(() {
      _vehicleType = value;
      _errorMessage = null;
    });
  }

  void _clearTextInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  }

  String? _validateRegistration(String? value) {
    final issue = IndianVehicleRegistration.issue(value);
    if (issue != null) return IndianVehicleRegistration.message(issue);
    return null;
  }

  String? _validateOptionalVehicleText(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  String? _normalizeRegistration(String? value) {
    return IndianVehicleRegistration.normalize(value);
  }

  bool _isVehicleType(String? value) => value == 'bike' || value == 'car';

  Future<void> _submit() async {
    _clearTextInputFocus();
    final vehicleType = _vehicleType;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (vehicleType == null) {
      setState(() => _errorMessage = 'Choose your vehicle type.');
      return;
    }
    if (!isValid) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(userSetupControllerProvider.notifier)
          .saveVehicleDetails(
            vehicleMake: _makeController.text,
            vehicleModel: _modelController.text,
            vehicleRegistration:
                _normalizeRegistration(_registrationController.text) ?? '',
            vehicleType: vehicleType,
          );
      if (mounted) context.go('/search');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _errorText(Object error) {
    if (error is AppFailure) return error.message;
    return 'Could not save your vehicle. Please try again.';
  }
}

class _VehicleDetailsFormContent extends StatelessWidget {
  const _VehicleDetailsFormContent({
    required this.errorMessage,
    required this.inputDecoration,
    required this.makeController,
    required this.modelController,
    required this.normalizeFocus,
    required this.onSelectVehicleType,
    required this.registrationController,
    required this.saving,
    required this.validateOptionalVehicleText,
    required this.validateRegistration,
    required this.vehicleType,
  });

  final String? errorMessage;
  final InputDecoration Function(String hint) inputDecoration;
  final TextEditingController makeController;
  final TextEditingController modelController;
  final VoidCallback normalizeFocus;
  final ValueChanged<String>? onSelectVehicleType;
  final TextEditingController registrationController;
  final bool saving;
  final FormFieldValidator<String> validateOptionalVehicleText;
  final FormFieldValidator<String> validateRegistration;
  final String? vehicleType;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: 'Vehicle type'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _VehicleTypeCard(
                icon: Icons.two_wheeler_rounded,
                label: 'Bike',
                selected: vehicleType == 'bike',
                onTap: onSelectVehicleType == null
                    ? null
                    : () => onSelectVehicleType!('bike'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VehicleTypeCard(
                icon: Icons.directions_car_filled_rounded,
                label: 'Car',
                selected: vehicleType == 'car',
                onTap: onSelectVehicleType == null
                    ? null
                    : () => onSelectVehicleType!('car'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FieldLabel(label: 'Registration number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: registrationController,
          enabled: !saving,
          inputFormatters: const [_IndianVehicleRegistrationFormatter()],
          keyboardType: TextInputType.text,
          onFieldSubmitted: (_) => normalizeFocus(),
          onTapOutside: (_) => normalizeFocus(),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          decoration: inputDecoration('TN 09 AB 1234'),
          validator: validateRegistration,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(label: 'Make'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: makeController,
                    enabled: !saving,
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    onTapOutside: (_) => normalizeFocus(),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: inputDecoration('Honda'),
                    validator: validateOptionalVehicleText,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(label: 'Model'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: modelController,
                    enabled: !saving,
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    onFieldSubmitted: (_) => normalizeFocus(),
                    onTapOutside: (_) => normalizeFocus(),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: inputDecoration('Activa'),
                    validator: validateOptionalVehicleText,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: Listenable.merge([
            makeController,
            modelController,
            registrationController,
          ]),
          builder: (context, _) {
            return _VehicleSummaryCard(
              make: makeController.text,
              model: modelController.text,
              registration: registrationController.text,
              vehicleType: vehicleType,
            );
          },
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          _SetupErrorBanner(message: errorMessage!),
        ],
      ],
    );
  }
}

class _SetupProgressAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const _SetupProgressAppBarBottom({required this.progress});

  final double progress;

  @override
  Size get preferredSize => const Size.fromHeight(5);

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();

    return Semantics(
      label: 'Setup progress',
      value: '${(value * 100).round()}%',
      child: SizedBox(
        height: preferredSize.height,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: Color(0xFFE4E4E7),
                child: SizedBox(height: 1),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              height: 3,
              width: MediaQuery.sizeOf(context).width * value,
              child: const ColoredBox(color: Color(0xFF0B0B0C)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0B0B0C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE4E4E7),
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF0B0B0C),
                size: 21,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF0B0B0C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleSummaryCard extends StatelessWidget {
  const _VehicleSummaryCard({
    required this.make,
    required this.model,
    required this.registration,
    required this.vehicleType,
  });

  final String make;
  final String model;
  final String registration;
  final String? vehicleType;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (vehicleType) {
      'bike' => 'Bike',
      'car' => 'Car',
      _ => 'Vehicle',
    };
    final normalizedRegistration = IndianVehicleRegistration.formatForDisplay(
      registration,
    );
    final subtitle = [
      if (make.trim().isNotEmpty) make.trim(),
      if (model.trim().isNotEmpty) model.trim(),
    ].join(' ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFB9F45E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  vehicleType == 'bike'
                      ? Icons.two_wheeler_rounded
                      : Icons.directions_car_filled_rounded,
                  color: const Color(0xFF0B0B0C),
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    normalizedRegistration.isEmpty
                        ? 'Registration pending'
                        : normalizedRegistration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: normalizedRegistration.isEmpty
                          ? const Color(0xFF71717A)
                          : const Color(0xFF0B0B0C),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndianVehicleRegistrationFormatter extends TextInputFormatter {
  const _IndianVehicleRegistrationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final nextText = IndianVehicleRegistration.inputText(newValue.text);
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }
}

class _IndianMobileNumberInputFormatter extends TextInputFormatter {
  const _IndianMobileNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final nextText = IndianMobileNumber.inputDigits(newValue.text);
    return TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF0B0B0C),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _PhoneCountryPrefix extends StatelessWidget {
  const _PhoneCountryPrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '+91',
            style: TextStyle(
              color: Color(0xFF0B0B0C),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 22, color: const Color(0xFFE4E4E7)),
        ],
      ),
    );
  }
}

class _SetupProfileAvatar extends StatelessWidget {
  const _SetupProfileAvatar({
    required this.avatarUrl,
    required this.fullName,
    required this.loading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String fullName;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasAvatar = url != null && url.isNotEmpty;
    final semanticLabel = hasAvatar
        ? 'Change profile photo'
        : 'Add profile photo';
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: semanticLabel,
            child: GestureDetector(
              onTap: onTap,
              child: RepaintBoundary(
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0B0B0C),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 9),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: ClipOval(
                              child: hasAvatar
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _AvatarInitials(fullName: fullName),
                                    )
                                  : _AvatarInitials(fullName: fullName),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFB9F45E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF0B0B0C),
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                      if (loading)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.fullName});

  final String fullName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18181B), Color(0xFF3F3F46)],
        ),
      ),
      child: Center(
        child: Text(
          profileInitials(fullName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SetupBottomAction extends StatelessWidget {
  const _SetupBottomAction({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.94),
            blurRadius: 18,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(59.4),
              backgroundColor: const Color(0xFF0B0B0C),
              disabledBackgroundColor: const Color(0xFF0B0B0C),
              disabledForegroundColor: Colors.white,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13.2),
              ),
              textStyle: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}

class _SetupOptionChip extends StatelessWidget {
  const _SetupOptionChip({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE4E4E7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13.2, vertical: 12.1),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF0B0B0C),
                fontSize: 13.2,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DobPickerSheet extends StatefulWidget {
  const _DobPickerSheet({
    required this.firstDate,
    required this.initialDate,
    required this.lastDate,
  });

  final DateTime firstDate;
  final DateTime initialDate;
  final DateTime lastDate;

  @override
  State<_DobPickerSheet> createState() => _DobPickerSheetState();
}

class _DobPickerSheetState extends State<_DobPickerSheet> {
  late DateTime _selectedDate = widget.initialDate;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(
      year: widget.initialDate.year,
      month: widget.initialDate.month,
      day: widget.initialDate.day,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _dayValues
          .indexOf(_selectedDate.day)
          .clamp(0, _dayValues.length - 1),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _monthValues
          .indexOf(_selectedDate.month)
          .clamp(0, _monthValues.length - 1),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedDate.year - widget.firstDate.year,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _formatLongDate(_selectedDate);

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E4E7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const SizedBox(width: 44, height: 5),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Date of birth',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF0B0B0C),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0B0C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.cake_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected date',
                                style: TextStyle(
                                  color: Color(0xFF71717A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                selectedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0B0B0C),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: SizedBox(
                    height: 206,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          brightness: Brightness.light,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: Color(0xFF0B0B0C),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: Column(
                            children: [
                              const _DobWheelHeader(),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Center(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B0B0C),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.12,
                                              ),
                                              blurRadius: 14,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const SizedBox(
                                          height: 42,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _DobWheel(
                                            controller: _dayController,
                                            itemCount: _dayValues.length,
                                            itemBuilder: (index) =>
                                                _dayValues[index]
                                                    .toString()
                                                    .padLeft(2, '0'),
                                            onSelectedItemChanged: (index) {
                                              _selectDate(
                                                day: _dayValues[index],
                                              );
                                            },
                                            selectedIndex: _dayValues.indexOf(
                                              _selectedDate.day,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: _DobWheel(
                                            controller: _monthController,
                                            itemCount: _monthValues.length,
                                            itemBuilder: (index) =>
                                                _monthName(_monthValues[index]),
                                            onSelectedItemChanged: (index) {
                                              _selectDate(
                                                month: _monthValues[index],
                                              );
                                            },
                                            selectedIndex: _monthValues.indexOf(
                                              _selectedDate.month,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: _DobWheel(
                                            controller: _yearController,
                                            itemCount: _yearValues.length,
                                            itemBuilder: (index) =>
                                                _yearValues[index].toString(),
                                            onSelectedItemChanged: (index) {
                                              _selectDate(
                                                year: _yearValues[index],
                                              );
                                            },
                                            selectedIndex: _yearValues.indexOf(
                                              _selectedDate.year,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: const Color(0xFF0B0B0C),
                          side: const BorderSide(color: Color(0xFFE4E4E7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedDate),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF0B0B0C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        child: const Text('Use date'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLongDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
  }

  List<int> get _dayValues {
    final firstDay =
        _selectedDate.year == widget.firstDate.year &&
            _selectedDate.month == widget.firstDate.month
        ? widget.firstDate.day
        : 1;
    final lastDay =
        _selectedDate.year == widget.lastDate.year &&
            _selectedDate.month == widget.lastDate.month
        ? widget.lastDate.day
        : _daysInMonth(_selectedDate.year, _selectedDate.month);
    return List<int>.generate(
      lastDay - firstDay + 1,
      (index) => firstDay + index,
    );
  }

  List<int> get _monthValues {
    final firstMonth = _selectedDate.year == widget.firstDate.year
        ? widget.firstDate.month
        : 1;
    final lastMonth = _selectedDate.year == widget.lastDate.year
        ? widget.lastDate.month
        : 12;
    return List<int>.generate(
      lastMonth - firstMonth + 1,
      (index) => firstMonth + index,
    );
  }

  List<int> get _yearValues {
    return List<int>.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
  }

  void _selectDate({int? day, int? month, int? year}) {
    final next = _normalizeDate(
      year: year ?? _selectedDate.year,
      month: month ?? _selectedDate.month,
      day: day ?? _selectedDate.day,
    );
    if (next == _selectedDate) {
      _syncWheelPositions();
      return;
    }
    setState(() => _selectedDate = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWheelPositions());
  }

  void _syncWheelPositions() {
    if (!mounted) return;
    final dayIndex = _dayValues.indexOf(_selectedDate.day);
    final monthIndex = _monthValues.indexOf(_selectedDate.month);
    final yearIndex = _yearValues.indexOf(_selectedDate.year);
    _jumpToItem(_dayController, dayIndex);
    _jumpToItem(_monthController, monthIndex);
    _jumpToItem(_yearController, yearIndex);
  }

  void _jumpToItem(FixedExtentScrollController controller, int index) {
    if (!controller.hasClients || index < 0) return;
    if (controller.selectedItem == index) return;
    controller.jumpToItem(index);
  }

  DateTime _normalizeDate({
    required int year,
    required int month,
    required int day,
  }) {
    final safeYear = year.clamp(widget.firstDate.year, widget.lastDate.year);
    final safeMonth = month.clamp(1, 12);
    final safeDay = day.clamp(1, _daysInMonth(safeYear, safeMonth));
    final date = DateTime(safeYear, safeMonth, safeDay);
    if (date.isBefore(widget.firstDate)) {
      return DateTime(
        widget.firstDate.year,
        widget.firstDate.month,
        widget.firstDate.day,
      );
    }
    if (date.isAfter(widget.lastDate)) {
      return DateTime(
        widget.lastDate.year,
        widget.lastDate.month,
        widget.lastDate.day,
      );
    }
    return date;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class _DobWheelHeader extends StatelessWidget {
  const _DobWheelHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 3, child: _DobWheelHeaderText('Date')),
        Expanded(flex: 5, child: _DobWheelHeaderText('Month')),
        Expanded(flex: 4, child: _DobWheelHeaderText('Year')),
      ],
    );
  }
}

class _DobWheelHeaderText extends StatelessWidget {
  const _DobWheelHeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF71717A),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _DobWheel extends StatelessWidget {
  const _DobWheel({
    required this.controller,
    required this.itemBuilder,
    required this.itemCount,
    required this.onSelectedItemChanged,
    required this.selectedIndex,
  });

  final FixedExtentScrollController controller;
  final String Function(int index) itemBuilder;
  final int itemCount;
  final ValueChanged<int> onSelectedItemChanged;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker.builder(
      backgroundColor: Colors.transparent,
      childCount: itemCount,
      itemExtent: 38,
      magnification: 1.06,
      onSelectedItemChanged: onSelectedItemChanged,
      scrollController: controller,
      selectionOverlay: const SizedBox.shrink(),
      squeeze: 1.04,
      useMagnifier: true,
      itemBuilder: (context, index) {
        final isSelected = index == selectedIndex;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              itemBuilder(index),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF71717A),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetupDatePickerTile extends StatelessWidget {
  const _SetupDatePickerTile({required this.onTap, required this.value});

  final VoidCallback? onTap;
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Choose date of birth'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return Material(
      color: const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF0B0B0C),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF0B0B0C),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF71717A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupErrorBanner extends StatelessWidget {
  const _SetupErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCCC7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
