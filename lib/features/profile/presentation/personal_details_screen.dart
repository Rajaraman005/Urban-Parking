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
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/profile_repository.dart';
import 'profile_details_controller.dart';
import 'profile_display.dart';

class PersonalDetailsScreen extends ConsumerWidget {
  const PersonalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final auth = authValue.value;
    final profileDisplay = ref.watch(currentProfileDisplayProvider);
    final profile = profileDisplay.profile ?? auth?.profile;
    final name = profileDisplay.displayName;
    final email = profileDisplay.displayEmail;
    final isSignedIn = profileDisplay.isSignedIn;
    final profileBusy = ref.watch(profileDetailsControllerProvider).isLoading;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      safeAreaBackgroundColor: const Color(0xFFB9F45E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PersonalDetailsHeader(
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            },
          ),
          Transform.translate(
            offset: const Offset(0, -52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                children: [
                  _EditableProfilePhoto(
                    avatarUrl: profile?.avatarUrl,
                    loading: profileBusy,
                    onEdit: profileBusy
                        ? null
                        : () => _pickAndUploadAvatar(context, ref),
                  ),
                  const SizedBox(height: 18),
                  _DetailsSection(
                    onEdit: profileBusy
                        ? null
                        : () => _openIdentityEditor(
                            auth: auth,
                            context: context,
                            displayName: name,
                            ref: ref,
                          ),
                    title: 'Identity',
                    children: [
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full name',
                        value: name,
                      ),
                      _DetailRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: email,
                      ),
                      _DetailRow(
                        icon: Icons.phone_iphone_rounded,
                        label: 'Mobile',
                        value: _emptyLabel(profile?.phone),
                        muted: _isBlank(profile?.phone),
                      ),
                      _DetailRow(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: _genderLabel(profile?.gender),
                        muted: _isBlank(profile?.gender),
                      ),
                      _DetailRow(
                        icon: Icons.cake_outlined,
                        label: 'Date of birth',
                        value: _dateLabel(profile?.dob),
                        muted: profile?.dob == null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailsSection(
                    title: 'Account',
                    children: [
                      _DetailRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Status',
                        value: isSignedIn ? 'Active' : 'Guest',
                      ),
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Intent',
                        value: _intentLabel(profile?.intent),
                      ),
                      _DetailRow(
                        icon: Icons.route_outlined,
                        label: 'Setup step',
                        value: _setupStepLabel(profile?.setupStep),
                      ),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Onboarding',
                        value: _dateLabel(profile?.onboardingCompletedAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailsSection(
                    title: 'Reference',
                    children: [
                      _DetailRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'User ID',
                        value: _shortId(auth?.user?.id),
                        monospaced: true,
                      ),
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Profile ID',
                        value: _shortId(profile?.id),
                        monospaced: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _intentLabel(String? intent) {
    return switch (intent?.trim()) {
      'park' => 'Find parking',
      'host' => 'Host spaces',
      String value when value.isNotEmpty => value,
      _ => 'Not selected',
    };
  }

  String _setupStepLabel(String? step) {
    final value = step?.trim();
    if (value == null || value.isEmpty) {
      return 'Not started';
    }

    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Not completed';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _shortId(String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) {
      return 'Unavailable';
    }
    if (id.length <= 12) {
      return id;
    }
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String _emptyLabel(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? 'Not added' : text;
  }

  String _genderLabel(String? gender) {
    return switch (gender?.trim()) {
      'male' => 'Male',
      'female' => 'Female',
      'other' => 'Other',
      'prefer_not_to_say' => 'Prefer not to say',
      String value when value.isNotEmpty => value,
      _ => 'Not added',
    };
  }

  void _openIdentityEditor({
    required AuthState? auth,
    required BuildContext context,
    required String displayName,
    required WidgetRef ref,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) => _IdentityEditSheet(
        initialDob: auth?.profile?.dob,
        initialFullName: displayName,
        initialGender: auth?.profile?.gender,
        initialPhone: auth?.profile?.phone,
        onSave: (update) async {
          try {
            await ref
                .read(profileDetailsControllerProvider.notifier)
                .updatePersonalDetails(update);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
            if (context.mounted) {
              _showToast(context, 'Details saved', AppToastVariant.success);
            }
          } catch (error) {
            if (context.mounted) {
              _showToast(context, _errorMessage(error), AppToastVariant.error);
            }
          }
        },
        version: auth?.profile?.version ?? 1,
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxHeight: 1800,
        maxWidth: 1800,
      );
      if (picked == null) {
        return;
      }

      var bytes = await picked.readAsBytes();
      var mimeType = picked.mimeType ?? _mimeTypeForName(picked.name);
      var fileName = picked.name.isEmpty ? 'profile-photo.jpg' : picked.name;

      if (bytes.length > 5 * 1024 * 1024) {
        bytes = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.jpeg,
          minHeight: 1200,
          minWidth: 1200,
          quality: 86,
        );
        mimeType = 'image/jpeg';
        fileName = '${_fileStem(fileName)}.jpg';
      }

      final dimensions = await _decodeImageSize(bytes);
      final image = ProfileAvatarUploadCandidate(
        bytes: bytes,
        fileName: fileName,
        height: dimensions.height.round(),
        mimeType: mimeType,
        width: dimensions.width.round(),
      );

      await ref
          .read(profileDetailsControllerProvider.notifier)
          .updateAvatar(image);

      if (context.mounted) {
        _showToast(context, 'Photo saved', AppToastVariant.success);
      }
    } catch (error) {
      if (context.mounted) {
        _showToast(context, _errorMessage(error), AppToastVariant.error);
      }
    }
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

  String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  String _fileStem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? 'profile-photo' : name.substring(0, dot);
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  void _showToast(
    BuildContext context,
    String message, [
    AppToastVariant variant = AppToastVariant.info,
  ]) {
    AppToast.show(context, message: message, variant: variant);
  }
}

class _PersonalDetailsHeader extends StatelessWidget {
  const _PersonalDetailsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFB9F45E),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 20, 58),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0B0B0C),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Personal details',
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
          ],
        ),
      ),
    );
  }
}

class _EditableProfilePhoto extends StatelessWidget {
  const _EditableProfilePhoto({
    required this.avatarUrl,
    required this.loading,
    required this.onEdit,
  });

  final String? avatarUrl;
  final bool loading;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Edit profile photo',
        child: GestureDetector(
          onTap: onEdit,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: _DetailsAvatar(avatarUrl: avatarUrl)),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                if (loading)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
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
    );
  }
}

class _DetailsAvatar extends StatelessWidget {
  const _DetailsAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();

    return ClipOval(
      child: SizedBox(
        width: 104,
        height: 104,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0C),
            border: Border.all(color: Colors.white, width: 4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: url == null || url.isEmpty
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 42,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _IdentityEditSheet extends StatefulWidget {
  const _IdentityEditSheet({
    required this.initialDob,
    required this.initialFullName,
    required this.initialGender,
    required this.initialPhone,
    required this.onSave,
    required this.version,
  });

  final DateTime? initialDob;
  final String initialFullName;
  final String? initialGender;
  final String? initialPhone;
  final Future<void> Function(ProfileDetailsUpdate update) onSave;
  final int version;

  @override
  State<_IdentityEditSheet> createState() => _IdentityEditSheetState();
}

class _IdentityEditSheetState extends State<_IdentityEditSheet> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  static const _genderOptions = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('other', 'Other'),
    ('prefer_not_to_say', 'Prefer not'),
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _dob = widget.initialDob;
    _gender = widget.initialGender;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                          'Edit identity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF0B0B0C),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _EditorLabel(label: 'Full name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameController,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Your full name'),
                  ),
                  const SizedBox(height: 14),
                  _EditorLabel(label: 'Mobile'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration('10 digit mobile number'),
                  ),
                  const SizedBox(height: 14),
                  _EditorLabel(label: 'Gender'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _genderOptions)
                        _OptionChip(
                          label: option.$2,
                          selected: _gender == option.$1,
                          onTap: _saving
                              ? null
                              : () => setState(() => _gender = option.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _EditorLabel(label: 'Date of birth'),
                  const SizedBox(height: 8),
                  _DatePickerTile(
                    value: _dob,
                    onTap: _saving ? null : _pickDob,
                    onClear: _saving || _dob == null
                        ? null
                        : () => setState(() => _dob = null),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: const Color(0xFF0B0B0C),
                            side: const BorderSide(color: Color(0xFF0B0B0C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF0B0B0C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text('Save details'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 100),
      initialDate: _dob ?? DateTime(now.year - 21, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        ProfileDetailsUpdate(
          expectedVersion: widget.version,
          fullName: _fullNameController.text,
          dob: _dob,
          gender: _gender,
          phone: _phoneController.text,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel({required this.label});

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

class _OptionChip extends StatelessWidget {
  const _OptionChip({
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE4E4E7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0B0B0C),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.onClear,
    required this.onTap,
    required this.value,
  });

  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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
                  value == null
                      ? 'Not added'
                      : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null
                        ? const Color(0xFF71717A)
                        : const Color(0xFF0B0B0C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear date',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.children,
    required this.title,
    this.onEdit,
  });

  final List<Widget> children;
  final VoidCallback? onEdit;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B0B0C),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit $title',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF0B0B0C),
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                    indent: 62,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospaced = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool monospaced;
  final bool muted;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, color: const Color(0xFF0B0B0C), size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF0B0B0C),
                    fontFamily: monospaced ? 'monospace' : null,
                    fontSize: 14,
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
    );
  }
}
