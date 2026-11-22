/// Form validators. Each returns an error message, or null when valid.
class Validators {
  const Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? fullName(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Name is required';
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(v)) {
      return '3-30 characters: lowercase letters, numbers, . or _';
    }
    return null;
  }
}
