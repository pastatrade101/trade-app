String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  if (!value.contains('@')) {
    return 'Enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.length < 6) {
    return 'Password must be at least 6 characters';
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
