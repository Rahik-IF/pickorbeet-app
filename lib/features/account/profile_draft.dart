/// Checks for the profile form, shared by the edit screen and the photo shortcut.
abstract final class ProfileDraft {
  static const maxPhotoBytes = 2 * 1024 * 1024;

  static String? nameError(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your $label.';
    if (trimmed.runes.length > 100) return 'Use 100 characters or fewer.';
    return null;
  }

  static String? phoneError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('88') && digits.length == 13) {
      digits = digits.substring(2);
    }
    if (digits.length == 10 && digits.startsWith('1')) digits = '0$digits';
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(digits)) {
      return 'Enter a Bangladeshi mobile number, such as 01712345678.';
    }
    return null;
  }

  static String? photoError(int length) {
    if (length <= 0) return 'Choose a photo to upload.';
    if (length > maxPhotoBytes) return 'Profile photos must be 2 MB or smaller.';
    return null;
  }

  static String? shortError(String value, {required int max, required String label}) {
    if (value.trim().runes.length > max) return '$label must be $max characters or fewer.';
    return null;
  }

  /// The server stores a new random name. Only the extension is kept from the picked file.
  static String filenameFor(String name) {
    final dot = name.lastIndexOf('.');
    final extension = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (extension == 'jpeg') return 'avatar.jpg';
    return allowed.contains(extension) ? 'avatar.$extension' : 'avatar.jpg';
  }
}
