class CountryOption {
  final String code;
  final String name;
  final String dialCode;
  final String flag;

  /// Fuseau IANA associé au pays (ex. "Africa/Douala"), renvoyé par /api/countries.
  final String? timezone;

  const CountryOption({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    this.timezone,
  });

  factory CountryOption.fromJson(Map<String, dynamic> json) {
    final tz = json['timezone']?.toString();
    return CountryOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dialCode: json['dialCode']?.toString() ?? '+237',
      flag: json['flag']?.toString() ?? '',
      timezone: (tz == null || tz.isEmpty) ? null : tz,
    );
  }

  static const fallback = CountryOption(
    code: 'CM',
    name: 'Cameroun',
    dialCode: '+237',
    flag: '🇨🇲',
    timezone: 'Africa/Douala',
  );

  /// Recherche insensible à la casse sur le nom, le code ISO et l'indicatif.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q) ||
        dialCode.replaceAll('+', '').contains(q.replaceAll('+', ''));
  }
}

/// Retrouve un pays dans la liste (fallback Cameroun).
CountryOption findCountry(String? code, List<CountryOption> countries) {
  if (code == null || code.isEmpty) return CountryOption.fallback;
  for (final c in countries) {
    if (c.code.toUpperCase() == code.toUpperCase()) return c;
  }
  return CountryOption.fallback;
}

/// Construit le numéro complet comme sur la version web (Auth.tsx).
String buildFullPhone(String phone, String selectedCountryCode, List<CountryOption> countries) {
  final trimmed = phone.trim();
  if (trimmed == 'admin' || trimmed == 'commercial') return trimmed;

  final country = findCountry(selectedCountryCode, countries);

  final cleanPhone = trimmed.replaceFirst(RegExp(r'^\+'), '');
  final cleanDialCode = country.dialCode.replaceFirst(RegExp(r'^\+'), '');
  if (cleanPhone.startsWith(cleanDialCode)) {
    return '+$cleanPhone';
  }
  return '${country.dialCode}$cleanPhone';
}
