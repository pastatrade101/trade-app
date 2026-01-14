String normalizeRole(String? value) {
  return (value ?? '').toLowerCase();
}

bool isAdmin(String? value) => normalizeRole(value) == 'admin';

bool isTrader(String? value) => normalizeRole(value) == 'trader';

bool isMember(String? value) => normalizeRole(value) == 'member';

bool isMemberOrTrader(String? value) => isMember(value) || isTrader(value);

String roleLabel(String? value) {
  final normalized = normalizeRole(value);
  switch (normalized) {
    case 'admin':
      return 'Admin';
    case 'trader':
      return 'Trader';
    case 'member':
      return 'Member';
    default:
      return 'Member';
  }
}
