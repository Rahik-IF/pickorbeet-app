import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/profile_draft.dart';
import 'package:pickorbeet/features/account/profile_photo.dart';
import 'package:pickorbeet/features/account/repositories/address_repository.dart';
import 'package:pickorbeet/features/account/view/widgets/bd_address_cascade.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';

/// Name, phone, delivery address, and profile photo. Email stays as the sign-in address.
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
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  var _division = '';
  var _district = '';
  var _postOffice = '';
  var _postal = '';
  var _city = '';
  String? _addressId;
  var _addressLabel = 'Home';
  var _addressCountry = 'Bangladesh';
  AddressModel? _seededDefault;
  var _hadDefaultAddress = false;
  var _profileFilled = false;
  var _addressSeeded = false;
  var _removeDefaultAddress = false;
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
      _applyProfile(user);
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
    _line1.dispose();
    _line2.dispose();
    super.dispose();
  }

  void _applyProfile(UserModel user) {
    _first.text = user.firstName;
    _last.text = user.lastName;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _profileFilled = true;
  }

  /// Only the true default delivery address. Otherwise keep profile text as a hint.
  void _seedAddress(List<AddressModel> addresses, UserModel user) {
    if (_addressSeeded) return;
    AddressModel? chosen;
    for (final item in addresses) {
      if (item.isDefault) {
        chosen = item;
        break;
      }
    }

    if (chosen != null) {
      _seededDefault = chosen;
      _hadDefaultAddress = true;
      _addressId = chosen.id;
      _addressLabel = chosen.label.trim().isEmpty ? 'Home' : chosen.label.trim();
      _addressCountry = chosen.country.trim().isEmpty ? 'Bangladesh' : chosen.country.trim();
      _line1.text = chosen.addressLine1;
      _line2.text = chosen.addressLine2;
      _division = chosen.division;
      _district = chosen.district;
      _postOffice = chosen.postOffice;
      _postal = chosen.postalCode;
      _city = chosen.city;
    } else {
      _seededDefault = null;
      _hadDefaultAddress = false;
      _addressId = null;
      _line1.text = user.address ?? '';
      _city = user.city ?? '';
      _postal = user.postalCode ?? '';
    }
    _addressSeeded = true;
  }

  void _applySeededDefault(AddressModel chosen) {
    _seededDefault = chosen;
    _hadDefaultAddress = true;
    _removeDefaultAddress = false;
    _addressId = chosen.id;
    _addressLabel = chosen.label.trim().isEmpty ? 'Home' : chosen.label.trim();
    _addressCountry = chosen.country.trim().isEmpty ? 'Bangladesh' : chosen.country.trim();
    _line1.text = chosen.addressLine1;
    _line2.text = chosen.addressLine2;
    _division = chosen.division;
    _district = chosen.district;
    _postOffice = chosen.postOffice;
    _postal = chosen.postalCode;
    _city = chosen.city;
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

  String get _streetSummary {
    final parts = [_line1.text.trim(), _line2.text.trim()].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  bool get _addressStarted {
    return _streetSummary.isNotEmpty ||
        _division.trim().isNotEmpty ||
        _district.trim().isNotEmpty ||
        _postOffice.trim().isNotEmpty ||
        _city.trim().isNotEmpty ||
        _postal.trim().isNotEmpty;
  }

  /// Explicit remove, or every address field emptied.
  bool get _clearingDefaultAddress =>
      _hadDefaultAddress && _addressId != null && (_removeDefaultAddress || !_addressStarted);

  void _markRemoveDefaultAddress() {
    setState(() {
      _removeDefaultAddress = true;
      _line1.clear();
      _line2.clear();
      _division = '';
      _district = '';
      _postOffice = '';
      _postal = '';
      _city = '';
      _errors = {..._errors}
        ..remove('address')
        ..remove('location')
        ..remove('city')
        ..remove('postal_code');
    });
  }

  void _undoRemoveDefaultAddress() {
    final seeded = _seededDefault;
    if (seeded == null) return;
    setState(() => _applySeededDefault(seeded));
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    void keep(String key, String? message) {
      if (message != null) errors[key] = message;
    }

    keep('first_name', ProfileDraft.nameError(_first.text, 'first name'));
    keep('last_name', ProfileDraft.nameError(_last.text, 'last name'));
    keep('phone', ProfileDraft.phoneError(_phone.text));
    if (_pending != null) keep('avatar', ProfileDraft.photoError(_pending!.length));

    if (_addressStarted && !_removeDefaultAddress) {
      if (_line1.text.trim().isEmpty) {
        keep('address', 'Enter your street address.');
      }
      if (_division.trim().isEmpty ||
          _district.trim().isEmpty ||
          _postOffice.trim().isEmpty ||
          _city.trim().isEmpty) {
        keep(
          'location',
          'Select division, district, post office, and city — same as your delivery address.',
        );
      }
      keep('city', ProfileDraft.shortError(_city, max: 100, label: 'City'));
      keep('postal_code', ProfileDraft.shortError(_postal, max: 20, label: 'Postal code'));
    }

    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
    });

    final phone = _phone.text.trim();
    final phoneApi = phone.isEmpty ? '' : Formatters.phoneForApi(phone);
    final fullName = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    final clearingDefault = _clearingDefaultAddress;
    final savingAddress = _addressStarted;

    // Delivery address first so a failed address write never leaves profile ahead of it.
    if (clearingDefault) {
      final removed = await ref.read(addressRepositoryProvider).remove(_addressId!);
      if (!mounted) return;
      final removeFailed = removed.fold((failure) {
        setState(() {
          _saving = false;
          _errors = {'location': failure.message};
        });
        showToast(context, failure.message, kind: ToastKind.error);
        return true;
      }, (_) {
        _addressId = null;
        _hadDefaultAddress = false;
        ref.invalidate(addressesProvider);
        return false;
      });
      if (removeFailed) return;
    } else if (savingAddress) {
      final draft = AddressModel(
        id: _addressId ?? '',
        label: _addressLabel.trim().isEmpty ? 'Home' : _addressLabel.trim(),
        fullName: fullName,
        phone: phoneApi.isNotEmpty ? phoneApi : phone,
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim(),
        division: _division.trim(),
        city: _city.trim(),
        district: _district.trim(),
        postOffice: _postOffice.trim(),
        postalCode: _postal.trim(),
        country: _addressCountry,
        isDefault: true,
      );
      final saved = await ref.read(addressRepositoryProvider).save(draft, id: _addressId);
      if (!mounted) return;
      final addressFailed = saved.fold((failure) {
        setState(() {
          _saving = false;
          _errors = {
            'location': failure.fieldErrors.values.isEmpty
                ? failure.message
                : failure.fieldErrors.values.first,
          };
        });
        showToast(context, failure.message, kind: ToastKind.error);
        return true;
      }, (address) {
        _addressId = address.id;
        _hadDefaultAddress = true;
        if (address.label.trim().isNotEmpty) _addressLabel = address.label.trim();
        ref.invalidate(addressesProvider);
        return false;
      });
      if (addressFailed) return;
    }

    final result = await ref.read(authRemoteRepositoryProvider).updateProfile(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          phone: phoneApi,
          address: _streetSummary,
          city: _city.trim(),
          postalCode: _postal.trim(),
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
        final addressNote = clearingDefault
            ? ' Default delivery address was removed, but profile details failed.'
            : savingAddress
                ? ' Delivery address was saved, but profile details failed.'
                : '';
        showToast(context, '${failure.message}$addressNote', kind: ToastKind.error);
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
    if (!_profileFilled && user != null) _applyProfile(user);

    final addressesAsync = ref.watch(addressesProvider);
    if (user != null && !_addressSeeded) {
      addressesAsync.when(
        data: (addresses) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _addressSeeded) return;
            setState(() => _seedAddress(addresses, user));
          });
        },
        error: (_, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _addressSeeded) return;
            setState(() => _seedAddress(const [], user));
          });
        },
        loading: () {},
      );
    }

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
                _Field(
                  controller: _first,
                  label: 'First name',
                  error: _errors['first_name'],
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _last,
                  label: 'Last name',
                  error: _errors['last_name'],
                  textInputAction: TextInputAction.next,
                  capitalization: TextCapitalization.words,
                ),
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
                const SizedBox(height: 18),
                Text(
                  'Delivery address',
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _removeDefaultAddress
                      ? 'Default delivery address will be removed when you save.'
                      : _hadDefaultAddress
                          ? 'Editing your default delivery address used at checkout.'
                          : 'No default delivery address yet. Fill this in to create one for checkout.',
                  style: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppPallete.inkSoft),
                ),
                if (addressesAsync.isLoading && !_addressSeeded) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2, color: AppPallete.primary),
                ],
                if (_removeDefaultAddress) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving ? null : _undoRemoveDefaultAddress,
                      child: const Text('Undo remove'),
                    ),
                  ),
                ] else ...[
                  if (_hadDefaultAddress) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _saving ? null : _markRemoveDefaultAddress,
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD14343)),
                        child: const Text('Remove default address'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _Field(
                    controller: _line1,
                    label: 'Street address',
                    hint: 'House, road, building',
                    error: _errors['address'],
                    textInputAction: TextInputAction.next,
                    capitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _line2,
                    label: 'Area or landmark',
                    hint: 'Optional',
                    textInputAction: TextInputAction.next,
                    capitalization: TextCapitalization.sentences,
                  ),
                  BdAddressCascade(
                    key: ValueKey('cascade-${_addressId ?? 'new'}'),
                    division: _division,
                    district: _district,
                    postOffice: _postOffice,
                    postalCode: _postal,
                    city: _city,
                    onChanged: ({
                      String? division,
                      String? district,
                      String? postOffice,
                      String? postalCode,
                      String? city,
                    }) {
                      setState(() {
                        if (division != null) _division = division;
                        if (district != null) _district = district;
                        if (postOffice != null) _postOffice = postOffice;
                        if (postalCode != null) _postal = postalCode;
                        if (city != null) _city = city;
                        _errors = {..._errors}
                          ..remove('location')
                          ..remove('city')
                          ..remove('postal_code');
                      });
                    },
                  ),
                  if (_errors['location'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errors['location']!,
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFFD14343)),
                    ),
                  ],
                  if (_errors['city'] != null || _errors['postal_code'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errors['city'] ?? _errors['postal_code']!,
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFFD14343)),
                    ),
                  ],
                ],
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
