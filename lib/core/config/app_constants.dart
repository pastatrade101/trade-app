class AppConstants {
  static const sessions = ['Asia', 'London', 'NewYork'];
  static const forexMajors = [
    InstrumentOption(symbol: 'EURUSD', label: 'EUR/USD'),
    InstrumentOption(symbol: 'GBPUSD', label: 'GBP/USD'),
    InstrumentOption(symbol: 'USDJPY', label: 'USD/JPY'),
    InstrumentOption(symbol: 'USDCHF', label: 'USD/CHF'),
    InstrumentOption(symbol: 'AUDUSD', label: 'AUD/USD'),
    InstrumentOption(symbol: 'USDCAD', label: 'USD/CAD'),
    InstrumentOption(symbol: 'NZDUSD', label: 'NZD/USD'),
  ];
  static const forexMinorCrosses = [
    InstrumentOption(symbol: 'EURGBP', label: 'EUR/GBP'),
    InstrumentOption(symbol: 'EURJPY', label: 'EUR/JPY'),
    InstrumentOption(symbol: 'EURCHF', label: 'EUR/CHF'),
    InstrumentOption(symbol: 'EURAUD', label: 'EUR/AUD'),
    InstrumentOption(symbol: 'EURCAD', label: 'EUR/CAD'),
    InstrumentOption(symbol: 'EURNZD', label: 'EUR/NZD'),
    InstrumentOption(symbol: 'GBPJPY', label: 'GBP/JPY'),
    InstrumentOption(symbol: 'GBPCHF', label: 'GBP/CHF'),
    InstrumentOption(symbol: 'GBPAUD', label: 'GBP/AUD'),
    InstrumentOption(symbol: 'GBPCAD', label: 'GBP/CAD'),
    InstrumentOption(symbol: 'GBPNZD', label: 'GBP/NZD'),
    InstrumentOption(symbol: 'AUDJPY', label: 'AUD/JPY'),
    InstrumentOption(symbol: 'AUDNZD', label: 'AUD/NZD'),
    InstrumentOption(symbol: 'AUDCAD', label: 'AUD/CAD'),
    InstrumentOption(symbol: 'AUDCHF', label: 'AUD/CHF'),
    InstrumentOption(symbol: 'CADJPY', label: 'CAD/JPY'),
    InstrumentOption(symbol: 'CADCHF', label: 'CAD/CHF'),
    InstrumentOption(symbol: 'NZDJPY', label: 'NZD/JPY'),
    InstrumentOption(symbol: 'NZDCHF', label: 'NZD/CHF'),
    InstrumentOption(symbol: 'CHFJPY', label: 'CHF/JPY'),
  ];
  static const forexEmergingExotics = [
    InstrumentOption(symbol: 'USDZAR', label: 'USD/ZAR'),
    InstrumentOption(symbol: 'USDTRY', label: 'USD/TRY'),
    InstrumentOption(symbol: 'USDMXN', label: 'USD/MXN'),
    InstrumentOption(symbol: 'USDSEK', label: 'USD/SEK'),
    InstrumentOption(symbol: 'USDNOK', label: 'USD/NOK'),
    InstrumentOption(symbol: 'USDDKK', label: 'USD/DKK'),
    InstrumentOption(symbol: 'USDPLN', label: 'USD/PLN'),
    InstrumentOption(symbol: 'USDHUF', label: 'USD/HUF'),
    InstrumentOption(symbol: 'USDCZK', label: 'USD/CZK'),
    InstrumentOption(symbol: 'USDSGD', label: 'USD/SGD'),
    InstrumentOption(symbol: 'USDHKD', label: 'USD/HKD'),
    InstrumentOption(symbol: 'USDILS', label: 'USD/ILS'),
    InstrumentOption(symbol: 'USDTHB', label: 'USD/THB'),
    InstrumentOption(symbol: 'USDCNH', label: 'USD/CNH'),
    InstrumentOption(symbol: 'EURTRY', label: 'EUR/TRY'),
    InstrumentOption(symbol: 'EURZAR', label: 'EUR/ZAR'),
    InstrumentOption(symbol: 'EURMXN', label: 'EUR/MXN'),
    InstrumentOption(symbol: 'GBPTRY', label: 'GBP/TRY'),
  ];
  static const indicesUs = [
    InstrumentOption(symbol: 'US30', label: 'US30 — Dow Jones (CFD)'),
    InstrumentOption(symbol: 'SPX500', label: 'SPX500 — S&P 500 (CFD)'),
    InstrumentOption(symbol: 'NAS100', label: 'NAS100 — Nasdaq 100 (CFD)'),
    InstrumentOption(symbol: 'US2000', label: 'US2000 — Russell 2000 (CFD)'),
  ];
  static const indicesEurope = [
    InstrumentOption(symbol: 'UK100', label: 'UK100 — FTSE 100 (CFD)'),
    InstrumentOption(symbol: 'GER30', label: 'GER30 — Germany 30 / DAX (CFD)'),
    InstrumentOption(symbol: 'FRA40', label: 'FRA40 — France 40 / CAC (CFD)'),
    InstrumentOption(symbol: 'EUSTX50', label: 'EUSTX50 — Euro Stoxx 50 (CFD)'),
    InstrumentOption(symbol: 'ESP35', label: 'ESP35 — Spain 35 / IBEX (CFD)'),
  ];
  static const indicesAsia = [
    InstrumentOption(symbol: 'JPN225', label: 'JPN225 — Japan 225 / Nikkei (CFD)'),
    InstrumentOption(symbol: 'HKG33', label: 'HKG33 — Hong Kong / Hang Seng (CFD)'),
    InstrumentOption(symbol: 'CHN50', label: 'CHN50 — China A50 (CFD)'),
    InstrumentOption(symbol: 'AUS200', label: 'AUS200 — Australia 200 (CFD)'),
  ];
  static const commodities = [
    InstrumentOption(symbol: 'XAUUSD', label: 'XAU/USD (Gold)'),
  ];
  static const crypto = [
    InstrumentOption(symbol: 'BTCUSD', label: 'BTC/USD'),
  ];
  static const instrumentCategories = [
    InstrumentCategory(
      id: 'forex_majors',
      label: 'Forex • Majors',
      options: forexMajors,
    ),
    InstrumentCategory(
      id: 'forex_minor_crosses',
      label: 'Forex • Minor Crosses',
      options: forexMinorCrosses,
    ),
    InstrumentCategory(
      id: 'forex_emerging_exotics',
      label: 'Forex • Emerging & Exotics',
      options: forexEmergingExotics,
    ),
    InstrumentCategory(
      id: 'indices_us',
      label: 'Indices • US',
      options: indicesUs,
    ),
    InstrumentCategory(
      id: 'indices_europe',
      label: 'Indices • Europe',
      options: indicesEurope,
    ),
    InstrumentCategory(
      id: 'indices_asia',
      label: 'Indices • Asia',
      options: indicesAsia,
    ),
    InstrumentCategory(
      id: 'commodities',
      label: 'Commodities',
      options: commodities,
    ),
    InstrumentCategory(
      id: 'crypto',
      label: 'Crypto',
      options: crypto,
    ),
  ];
  static List<InstrumentOption> get instrumentOptions => [
        for (final category in instrumentCategories) ...category.options,
      ];
  static List<String> get instruments => [
        for (final option in instrumentOptions) option.symbol,
      ];
  static Map<String, String> get instrumentLabels => {
        for (final option in instrumentOptions)
          option.symbol: option.label,
      };
  static const strategyStyles = ['Scalper', 'Swing'];
  static const experienceLevels = ['Beginner', 'Intermediate', 'Advanced'];
  static const riskLevels = ['Low', 'Medium', 'High'];
  static const directionOptions = ['Buy', 'Sell'];
  static const entryTypes = ['Market', 'Limit', 'Breakout'];
  static const reportReasons = ['Spam', 'Inaccurate', 'Abusive', 'Other'];

  static const int minConsensusVotes = 5;
  static const double minConsensusAgreement = 0.7;
  static const double minConsensusWeight = 6.0;
  static const int minAccountAgeHoursForVote = 12;
  static const double reputationThreshold = 60;
}

class InstrumentOption {
  final String symbol;
  final String label;

  const InstrumentOption({required this.symbol, required this.label});
}

class InstrumentCategory {
  final String id;
  final String label;
  final List<InstrumentOption> options;

  const InstrumentCategory({
    required this.id,
    required this.label,
    required this.options,
  });
}
