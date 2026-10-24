import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/features/account/profile_draft.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';

/// What the customer chose from the photo sheet.
sealed class ProfilePhotoChoice {
  const ProfilePhotoChoice();
}

final class ProfilePhotoUpload extends ProfilePhotoChoice {
  const ProfilePhotoUpload(this.bytes, this.filename);

  final Uint8List bytes;
  final String filename;
}

final class ProfilePhotoRemove extends ProfilePhotoChoice {
  const ProfilePhotoRemove();
}

final class ProfilePhotoInvalid extends ProfilePhotoChoice {
  const ProfilePhotoInvalid(this.message);

  final String message;
}

enum _PhotoAction { camera, gallery, remove }

/// Camera, gallery, or remove. Returns null when the sheet or the picker is dismissed.
Future<ProfilePhotoChoice?> chooseProfilePhoto(BuildContext context, {required bool canRemove}) async {
  final action = await showModalBottomSheet<_PhotoAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Profile photo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'JPEG, PNG, or WebP, up to 2 MB.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.camera),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.image),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, _PhotoAction.gallery),
              ),
              if (canRemove)
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.trash, color: Color(0xFFD14343)),
                  title: const Text('Remove photo', style: TextStyle(color: Color(0xFFD14343))),
                  onTap: () => Navigator.pop(context, _PhotoAction.remove),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (action == null || !context.mounted) return null;
  if (action == _PhotoAction.remove) return const ProfilePhotoRemove();

  try {
    final photo = await ImagePicker().pickImage(
      source: action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (photo == null) return null;
    final bytes = await photo.readAsBytes();
    final problem = ProfileDraft.photoError(bytes.length);
    if (problem != null) return ProfilePhotoInvalid(problem);
    return ProfilePhotoUpload(bytes, ProfileDraft.filenameFor(photo.name));
  } on PlatformException catch (error) {
    return ProfilePhotoInvalid(_pickerMessage(error));
  } on Object {
    return const ProfilePhotoInvalid('Could not open your photos. Try again.');
  }
}

String _pickerMessage(PlatformException error) {
  return switch (error.code) {
    'camera_access_denied' || 'camera_access_restricted' => 'Allow camera access to take a profile photo.',
    'photo_access_denied' || 'photo_access_restricted' => 'Allow photo access to choose a profile photo.',
    _ => 'Could not open your photos. Try again.',
  };
}

/// Uploads or removes the photo immediately and keeps the signed-in profile in sync.
Future<String?> saveProfilePhoto(WidgetRef ref, ProfilePhotoChoice choice) async {
  if (choice is ProfilePhotoInvalid) return choice.message;
  final repository = ref.read(authRemoteRepositoryProvider);
  final result = switch (choice) {
    ProfilePhotoUpload(:final bytes, :final filename) => await repository.updateProfile(
      avatarBytes: bytes,
      avatarFilename: filename,
    ),
    ProfilePhotoRemove() => await repository.updateProfile(clearAvatar: true),
    ProfilePhotoInvalid() => null,
  };
  return result?.fold((failure) => failure.message, (user) {
    ref.read(currentUserNotifierProvider.notifier).setUser(user);
    return null;
  });
}

/// Round photo with a camera badge. [bytes] wins over [imageUrl] so a picked photo shows before save.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.bytes,
    this.initials = '',
    this.onTap,
    this.busy = false,
    this.background = const Color(0xFFE7EEFB),
    this.badgeColor = AppPallete.primary,
    this.badgeBorder = AppPallete.surface,
    this.placeholder,
  });

  final double size;
  final String? imageUrl;
  final Uint8List? bytes;
  final String initials;
  final VoidCallback? onTap;
  final bool busy;
  final Color background;
  final Color badgeColor;
  final Color badgeBorder;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final photo = _photo();
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Pressable(
            semanticLabel: 'Change profile photo',
            enabled: onTap != null && !busy,
            onTap: busy ? null : onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: background, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: photo,
            ),
          ),
          if (busy)
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Pressable(
              semanticLabel: 'Change profile photo',
              enabled: onTap != null && !busy,
              onTap: busy ? null : onTap,
              child: Container(
                width: size < 60 ? 18 : 22,
                height: size < 60 ? 18 : 22,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeBorder, width: size < 60 ? 1.5 : 2),
                ),
                alignment: Alignment.center,
                child: Icon(PhosphorIconsFill.camera, size: size < 60 ? 9 : 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo() {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return AppNetworkImage(url: url, background: background, placeholderIcon: PhosphorIconsRegular.user);
    }
    if (placeholder != null) return placeholder!;
    if (initials.trim().isNotEmpty) {
      return Text(
        initials,
        style: AppTypography.titleMedium.copyWith(color: AppPallete.primaryText, fontSize: size * 0.32, fontWeight: FontWeight.w700),
      );
    }
    return Icon(PhosphorIconsRegular.user, size: size * 0.5, color: const Color(0xFF8AA0C8));
  }
}

/// Whether the signed-in customer currently has a photo the shortcut can remove.
bool profileHasPhoto(UserModel? user) {
  final url = user?.avatar?.trim() ?? '';
  return url.isNotEmpty;
}
