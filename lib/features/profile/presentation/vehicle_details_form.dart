import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/validation/indian_vehicle_registration.dart';
import '../domain/profile_vehicle.dart';

typedef VehicleDetailsSave =
    Future<void> Function({
      String? vehicleMake,
      String? vehicleModel,
      required String vehicleRegistration,
      required String vehicleType,
    });

class VehicleDetailsForm extends StatefulWidget {
  const VehicleDetailsForm({
    required this.onSave,
    super.key,
    this.initialMake,
    this.initialModel,
    this.initialRegistration,
    this.initialType,
    this.onSavingChanged,
    this.onTextInputFocusChanged,
    this.savedVehicles = const [],
    this.savedVehiclesLoading = false,
    this.showSaveButton = false,
    this.showSavedVehicles = true,
  });

  final String? initialMake;
  final String? initialModel;
  final String? initialRegistration;
  final String? initialType;
  final ValueChanged<bool>? onSavingChanged;
  final ValueChanged<bool>? onTextInputFocusChanged;
  final List<ProfileVehicle> savedVehicles;
  final bool savedVehiclesLoading;
  final VehicleDetailsSave onSave;
  final bool showSaveButton;
  final bool showSavedVehicles;

  @override
  State<VehicleDetailsForm> createState() => VehicleDetailsFormState();
}

class VehicleDetailsFormState extends State<VehicleDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _registrationController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final FocusNode _registrationFocusNode;
  late final FocusNode _makeFocusNode;
  late final FocusNode _modelFocusNode;
  String? _vehicleType;
  String? _errorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _registrationController = TextEditingController(
      text: IndianVehicleRegistration.inputText(
        widget.initialRegistration ?? '',
      ),
    );
    _makeController = TextEditingController(text: widget.initialMake ?? '');
    _modelController = TextEditingController(text: widget.initialModel ?? '');
    _registrationFocusNode = FocusNode();
    _makeFocusNode = FocusNode();
    _modelFocusNode = FocusNode();
    _registrationFocusNode.addListener(_handleTextInputFocusChange);
    _makeFocusNode.addListener(_handleTextInputFocusChange);
    _modelFocusNode.addListener(_handleTextInputFocusChange);
    final initialType = widget.initialType?.trim().toLowerCase();
    _vehicleType = _isEditableVehicleType(initialType) ? initialType : null;
  }

  @override
  void didUpdateWidget(covariant VehicleDetailsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRegistration = IndianVehicleRegistration.inputText(
      oldWidget.initialRegistration ?? '',
    );
    final nextRegistration = IndianVehicleRegistration.inputText(
      widget.initialRegistration ?? '',
    );
    if (oldRegistration == nextRegistration) return;

    final currentRegistration = IndianVehicleRegistration.inputText(
      _registrationController.text,
    );
    final canReseed =
        currentRegistration.isEmpty || currentRegistration == oldRegistration;
    if (!canReseed) return;

    _registrationController.text = nextRegistration;
    _makeController.text = widget.initialMake ?? '';
    _modelController.text = widget.initialModel ?? '';
    final initialType = widget.initialType?.trim().toLowerCase();
    setState(() {
      _vehicleType = _isEditableVehicleType(initialType) ? initialType : null;
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _registrationFocusNode.removeListener(_handleTextInputFocusChange);
    _makeFocusNode.removeListener(_handleTextInputFocusChange);
    _modelFocusNode.removeListener(_handleTextInputFocusChange);
    _registrationFocusNode.dispose();
    _makeFocusNode.dispose();
    _modelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _VehicleEditorLabel(label: 'Vehicle type'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _VehicleTypeOption(
                  icon: Icons.two_wheeler_rounded,
                  label: 'Bike',
                  selected: _vehicleType == 'bike',
                  onTap: _saving ? null : () => _selectVehicleType('bike'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VehicleTypeOption(
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Car',
                  selected: _vehicleType == 'car',
                  onTap: _saving ? null : () => _selectVehicleType('car'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _VehicleEditorLabel(label: 'Registration number'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _registrationController,
            enabled: !_saving,
            focusNode: _registrationFocusNode,
            inputFormatters: const [_IndianVehicleRegistrationFormatter()],
            keyboardType: TextInputType.text,
            onFieldSubmitted: (_) => _clearTextInputFocus(),
            onTapOutside: (_) => _clearTextInputFocus(),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('TN 09 AB 1234'),
            validator: _validateRegistration,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _VehicleEditorLabel(label: 'Make'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _makeController,
                      enabled: !_saving,
                      focusNode: _makeFocusNode,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      onTapOutside: (_) => _clearTextInputFocus(),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration('Honda'),
                      validator: _validateOptionalVehicleText,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _VehicleEditorLabel(label: 'Model'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _modelController,
                      enabled: !_saving,
                      focusNode: _modelFocusNode,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      onFieldSubmitted: (_) => _clearTextInputFocus(),
                      onTapOutside: (_) => _clearTextInputFocus(),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: _inputDecoration('Activa'),
                      validator: _validateOptionalVehicleText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: Listenable.merge([
              _makeController,
              _modelController,
              _registrationController,
            ]),
            builder: (context, _) {
              if (!_shouldShowLivePreview) return const SizedBox.shrink();
              return _VehiclePreviewCard(
                make: _makeController.text,
                model: _modelController.text,
                registration: _registrationController.text,
                vehicleType: _vehicleType,
              );
            },
          ),
          if (widget.savedVehiclesLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (widget.showSavedVehicles && widget.savedVehicles.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _VehicleEditorLabel(label: 'Saved vehicles'),
            const SizedBox(height: 10),
            for (final vehicle in widget.savedVehicles) ...[
              _SavedVehicleCard(
                vehicle: vehicle,
                onTap: _saving ? null : () => _editSavedVehicle(vehicle),
              ),
              if (vehicle != widget.savedVehicles.last)
                const SizedBox(height: 10),
            ],
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _VehicleEditorError(message: _errorMessage!),
          ],
          if (_shouldShowInlineSaveButton(context)) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF0B0B0C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(_saving ? 'Saving' : 'Save vehicle'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> save() => _save();

  void resetForNewVehicle() {
    _clearTextInputFocus();
    _registrationController.clear();
    _makeController.clear();
    _modelController.clear();
    setState(() {
      _vehicleType = null;
      _errorMessage = null;
    });
  }

  void _editSavedVehicle(ProfileVehicle vehicle) {
    _clearTextInputFocus();
    _registrationController.text = IndianVehicleRegistration.inputText(
      vehicle.registration,
    );
    _makeController.text = vehicle.make ?? '';
    _modelController.text = vehicle.model ?? '';
    setState(() {
      _vehicleType = _isEditableVehicleType(vehicle.type)
          ? vehicle.type.trim().toLowerCase()
          : null;
      _errorMessage = null;
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
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
    return issue == null ? null : IndianVehicleRegistration.message(issue);
  }

  String? _validateOptionalVehicleText(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    _clearTextInputFocus();
    final vehicleType = _vehicleType;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (vehicleType == null) {
      setState(() => _errorMessage = 'Choose your vehicle type.');
      return;
    }
    if (!isValid) return;

    _setSaving(true);
    setState(() => _errorMessage = null);

    try {
      await widget.onSave(
        vehicleMake: _makeController.text,
        vehicleModel: _modelController.text,
        vehicleRegistration:
            IndianVehicleRegistration.normalize(_registrationController.text) ??
            '',
        vehicleType: vehicleType,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorText(error));
    } finally {
      if (mounted) {
        _setSaving(false);
      }
    }
  }

  void _setSaving(bool value) {
    setState(() => _saving = value);
    widget.onSavingChanged?.call(value);
  }

  String _errorText(Object error) {
    if (error is AppFailure) return error.message;
    return 'Could not save your vehicle. Please try again.';
  }

  bool _isEditableVehicleType(String? value) =>
      value == 'bike' || value == 'car';

  bool _shouldShowInlineSaveButton(BuildContext context) {
    return widget.showSaveButton &&
        !_hasTextInputFocus &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  bool get _shouldShowLivePreview {
    if (widget.savedVehicles.isEmpty) return true;
    final registration = IndianVehicleRegistration.normalize(
      _registrationController.text,
    );
    if (registration == null || registration.isEmpty) return true;
    return !widget.savedVehicles.any(
      (vehicle) => vehicle.registration == registration,
    );
  }

  bool get _hasTextInputFocus =>
      _registrationFocusNode.hasFocus ||
      _makeFocusNode.hasFocus ||
      _modelFocusNode.hasFocus;

  void _handleTextInputFocusChange() {
    widget.onTextInputFocusChanged?.call(_hasTextInputFocus);
    if (widget.showSaveButton && mounted) {
      setState(() {});
    }
  }
}

class _VehicleEditorLabel extends StatelessWidget {
  const _VehicleEditorLabel({required this.label});

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

class _VehicleTypeOption extends StatelessWidget {
  const _VehicleTypeOption({
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

class _VehiclePreviewCard extends StatelessWidget {
  const _VehiclePreviewCard({
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
    final normalizedRegistration = IndianVehicleRegistration.formatForDisplay(
      registration,
    );
    final makeModel = _makeModelLabel(make, model);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
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
                  _vehicleIcon(vehicleType),
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
                    _vehicleTypeLabel(vehicleType),
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
                  if (makeModel.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      makeModel,
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

class _SavedVehicleCard extends StatelessWidget {
  const _SavedVehicleCard({required this.onTap, required this.vehicle});

  final VoidCallback? onTap;
  final ProfileVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final makeModel = _makeModelLabel(vehicle.make, vehicle.model);

    return Material(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    _vehicleIcon(vehicle.type),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _vehicleTypeLabel(vehicle.type),
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
                        ),
                        if (vehicle.isPrimary) ...[
                          const SizedBox(width: 8),
                          const _PrimaryVehicleBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      vehicle.displayRegistration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B0B0C),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    if (makeModel.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        makeModel,
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
      ),
    );
  }
}

class _PrimaryVehicleBadge extends StatelessWidget {
  const _PrimaryVehicleBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          'Primary',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _VehicleEditorError extends StatelessWidget {
  const _VehicleEditorError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDA29B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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

IconData _vehicleIcon(String? type) {
  return switch (type?.trim().toLowerCase()) {
    'bike' => Icons.two_wheeler_rounded,
    'car' => Icons.directions_car_filled_rounded,
    _ => Icons.directions_car_outlined,
  };
}

String _vehicleTypeLabel(String? type) {
  return switch (type?.trim().toLowerCase()) {
    'bike' => 'Bike',
    'car' => 'Car',
    String value when value.isNotEmpty => type!.trim(),
    _ => 'Vehicle',
  };
}

String _makeModelLabel(String? make, String? model) {
  final parts = [
    if (make != null && make.trim().isNotEmpty) make.trim(),
    if (model != null && model.trim().isNotEmpty) model.trim(),
  ];
  return parts.join(' ');
}
