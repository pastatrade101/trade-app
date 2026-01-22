String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  if (!value.contains('@')) {
    return 'Enter a valid email';
  }
  return null;
}

const int _passwordMinLength = 8;
const int _passwordMaxLength = 64;
const String _passwordPolicyPattern =
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9])\S{8,64}$';
final RegExp _passwordPolicyRegex = RegExp(_passwordPolicyPattern);
final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
final RegExp _lowercaseRegex = RegExp(r'[a-z]');
final RegExp _digitRegex = RegExp(r'\d');
final RegExp _specialRegex = RegExp(r'[^A-Za-z0-9]');
final RegExp _whitespaceRegex = RegExp(r'\s');

String? validatePassword(String? value, {bool enforcePolicy = true}) {
  final raw = value ?? '';
  if (raw.trim().isEmpty) {
    return 'Password is required';
  }
  if (!enforcePolicy) {
    return null;
  }
  if (raw.length < _passwordMinLength) {
    return 'Password must be at least $_passwordMinLength characters';
  }
  if (raw.length > _passwordMaxLength) {
    return 'Password must be at most $_passwordMaxLength characters';
  }
  if (_whitespaceRegex.hasMatch(raw)) {
    return 'Password must not contain spaces';
  }
  if (!_uppercaseRegex.hasMatch(raw)) {
    return 'Password must include at least 1 uppercase letter (A-Z)';
  }
  if (!_lowercaseRegex.hasMatch(raw)) {
    return 'Password must include at least 1 lowercase letter (a-z)';
  }
  if (!_digitRegex.hasMatch(raw)) {
    return 'Password must include at least 1 number (0-9)';
  }
  if (!_specialRegex.hasMatch(raw)) {
    return 'Password must include at least 1 special character';
  }
  if (!_passwordPolicyRegex.hasMatch(raw)) {
    return 'Password does not meet complexity requirements';
  }
  return null;
}

String? validateRequired(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? validateUsername(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Username is required';
  }
  final trimmed = value.trim();
  if (trimmed.length < 3) {
    return 'Username must be at least 3 characters';
  }
  final regex = RegExp(r'^[a-zA-Z0-9_]+$');
  if (!regex.hasMatch(trimmed)) {
    return 'Username can contain letters, numbers, underscore';
  }
  return null;
}
