abstract final class FieldValidator {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _slug = RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$');
  static final _currency = RegExp(r'^[A-Z]{3}$');

  static String? email(String value) {
    final trimmed = value.trim();
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  static String? signInPassword(String value) {
    if (value.isEmpty) return 'Enter your password.';
    return null;
  }

  static String? signUpPassword(String value) {
    if (value.length < 10) return 'Use at least 10 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Use at least one letter and one number.';
    }
    return null;
  }

  static String? displayName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 60) {
      return 'Use 2 to 60 characters.';
    }
    return null;
  }

  static String? organizationName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 80) {
      return 'Use 2 to 80 characters.';
    }
    return null;
  }

  static String? slug(String value) {
    if (!_slug.hasMatch(value.trim())) {
      return 'Use 3 to 40 lowercase letters, numbers, or hyphens.';
    }
    return null;
  }

  static String? currency(String value) {
    if (!_currency.hasMatch(value.trim())) return 'Use a code such as USD.';
    return null;
  }

  static String? required(String value, String label) {
    if (value.trim().isEmpty) return 'Enter $label.';
    return null;
  }

  static String slugFromName(String name) {
    final lowered = name.trim().toLowerCase();
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final collapsed = replaced.replaceAll(RegExp(r'-{2,}'), '-');
    var slug = collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length < 3) slug = '${slug}club'.padRight(3, 'x');
    if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
    if (slug.length < 3) slug = 'club';
    return slug;
  }
}
