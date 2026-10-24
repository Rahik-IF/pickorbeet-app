import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/profile_draft.dart';
import 'package:pickorbeet/features/account/profile_photo.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';

/// Name, phone, address, and profile photo. Email stays as the sign-in address.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  var _filled = false;
  var _saving = false;
  var _removePhoto = false;
  Uint8List? _pending;
  String? _pendingName;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserNotifierProvider);
    if (user != null) {
      _apply(user);
    } else {
      Future.microtask(() => ref.read(sessionNotifierProvider.notifier).refreshProfile());
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _postal.dispose();
    super.dispose();
  }

  void _apply(UserModel user) {
    _first.text = user.firstName;
    _last.text = user.lastName;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _address.text = user.address ?? '';
    _city.text = user.city ?? '';
    _postal.text = user.postalCode ?? '';
    _filled = true;
  }

  Future<void> _choosePhoto(UserModel user) async {
    if (_saving) return;
    final choice = await chooseProfilePhoto(
      context,
      canRemove: _pending != null || (!_removePhoto && profileHasPhoto(user)),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case ProfilePhotoInvalid(:final message):
        showToast(context, message, kind: ToastKind.error);
      case ProfilePhotoRemove():
        setState(() {
          _pending = null;
          _pendingName = null;
          _removePhoto = true;
          _errors = {..._errors}..remove('avatar');
        });
      case ProfilePhotoUpload(:final bytes, :final filename):
        setState(() {
          _pending = bytes;
          _pendingName = filename;
          _removePhoto = false;
          _errors = {..._errors}..remove('avatar');
        });
    }
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    void keep(String key, String? message) {
      if (message != null) errors[key] = message;
    }

    keep('first_name', ProfileDraft.nameError(_first.text, 'first name'));
    keep('last_name', ProfileDraft.nameError(_last.text, 'last name'));
    keep('phone', ProfileDraft.phoneError(_phone.text));
    keep('city', ProfileDraft.shortError(_city.text, max: 100, label: 'City'));
    keep('postal_code', ProfileDraft.shortError(_postal.text, max: 20, label: 'Postal code'));
    if (_pending != null) keep('avatar', ProfileDraft.photoError(_pending!.length));
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
    });
    final phone = _phone.text.trim();
    final result = await ref.read(authRemoteRepositoryProvider).updateProfile(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      phone: phone.isEmpty ? '' : Formatters.phoneForApi(phone),
      address: _address.text.trim(),
      city: _city.text.trim(),
      postalCode: _postal.text.trim(),
      avatarBytes: _pending,
      avatarFilename: _pendingName,
      clearAvatar: _removePhoto && _pending == null,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _saving = false;
          _errors = failure.fieldErrors;
        });
        showToast(context, failure.message, kind: ToastKind.error);
      },
      (user) {
        ref.read(currentUserNotifierProvider.notifier).setUser(user);
        showToast(context, 'Profile updated', kind: ToastKind.success);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserNotifierProvider);
    if (!_filled && user != null) _apply(user);

    return Scaffold(
      backgroundColor: AppPallete.background,
      appBar: AppBar(
        backgroundColor: AppPallete.surface,
        foregroundColor: AppPallete.ink,
        elevation: 0,
        title: Text('Edit profile', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppPallete.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Center(
                  child: ProfileAvatar(
                    size: 96,
                    bytes: _pending,
                    imageUrl: _removePhoto ? null : user.avatar,
                    initials: user.initials,
                    busy: _saving && _pending != null,
                    onTap: () => _choosePhoto(user),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the photo to take a new one, choose from your gallery, or remove it.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(color: AppPallete.inkSoft),
                ),
                if (_errors['avatar'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errors['avatar']!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: const Color(0xFFD14343)),
                  ),
                ],
                const SizedBox(height: 22),
                _Field(controller: _first, label: 'First name', error: _errors['first_name'], textInputAction: TextInputAction.next, capitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _Field(controller: _last, label: 'Last name', error: _errors['last_name'], textInputAction: TextInputAction.next, capitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _Field(controller: _email, label: 'Email', readOnly: true),
                const SizedBox(height: 6),
                Text(
                  'Email is your sign-in address and stays the same.',
                  style: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppPallete.inkSoft),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _phone,
                  label: 'Phone',
                  hint: '01712345678',
                  error: _errors['phone'],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _address,
                  label: 'Address',
                  hint: 'House, road, area',
                  error: _errors['address'],
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _city,
                  label: 'City',
                  error: _errors['city'],
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _postal,
                  label: 'Postal code',
                  error: _errors['postal_code'],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPallete.primary,
                    disabledBackgroundColor: AppPallete.primary.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Save changes', style: AppTypography.label.copyWith(color: AppPallete.onDark, fontSize: 15)),
                ),
              ],
            ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.error,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.readOnly = false,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE3E8F4)),
    );
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: capitalization,
      style: AppTypography.bodyMedium.copyWith(color: readOnly ? AppPallete.inkSoft : AppPallete.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF2F5FB) : const Color(0xFFF7F9FD),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPallete.primary, width: 1.4),
        ),
      ),
    );
  }
}
