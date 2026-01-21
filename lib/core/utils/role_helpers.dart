String normalizeRole(String? value) {
  return (value ?? '').toLowerCase();
}

bool isAdmin(String? value) => normalizeRole(value) == 'admin';

bool isTraderAdmin(String? value) => normalizeRole(value) == 'trader_admin';

bool isAdminOrTraderAdmin(String? value) =>
    isAdmin(value) || isTraderAdmin(value);

bool isTrader(String? value) =>
    normalizeRole(value) == 'trader' || isTraderAdmin(value);

bool isMember(String? value) => normalizeRole(value) == 'member';

bool isMemberOrTrader(String? value) => isMember(value) || isTrader(value);

String roleLabel(String? value) {
  final normalized = normalizeRole(value);
  switch (normalized) {
    case 'admin':
      return 'Admin';
    case 'trader_admin':
      return 'Trader Admin';
    case 'trader':
      return 'Trader';
    case 'member':
      return 'Member';
    default:
      return 'Member';
  }
}
