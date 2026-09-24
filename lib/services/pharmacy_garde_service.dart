import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

// ============================================================================
// Modèles
// ============================================================================

/// Une pharmacie retournée par l'API api-pharmacie (source : OpenStreetMap).
class PharmacyGarde {
  final String osmId;
  final String name;
  final String city;
  final String? address;
  final List<String> phones;
  final double lat;
  final double lng;
  final String sourceUrl;
  final bool isOnDuty;

  /// Distance en km depuis la position de l'utilisateur (recherche « à proximité »).
  final double? distanceKm;

  PharmacyGarde({
    required this.osmId,
    required this.name,
    required this.city,
    this.address,
    required this.phones,
    required this.lat,
    required this.lng,
    required this.sourceUrl,
    this.isOnDuty = false,
    this.distanceKm,
  });

  bool get hasLocation => lat != 0.0 || lng != 0.0;

  String? _searchKey;

  /// Texte normalisé (sans accents/casse) utilisé par les filtres locaux ;
  /// calculé une seule fois plutôt qu'à chaque frappe.
  String get searchKey => _searchKey ??= normalizeSearchText('$name ${address ?? ''} $city');

  /// Construit une pharmacie à partir d'un élément de `GET /pharmacies/nearby`
  /// (clés `name`/`nom_pharmacie`, `phone`, `latitude`/`longitude`, `est_garde`, `distance`).
  factory PharmacyGarde.fromNearby(Map<String, dynamic> json) {
    final rawPhones = json['phones'];
    final phones = <String>[];
    if (rawPhones is List) {
      phones.addAll(rawPhones.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
    }
    final single = json['phone']?.toString().trim();
    if (single != null && single.isNotEmpty && !phones.contains(single)) phones.insert(0, single);

    double? toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    final city = (json['ville'] ?? json['city'] ?? json['region'] ?? '').toString();
    final id = (json['id'] ?? json['id_pharmacie'] ?? json['osmId'] ?? '').toString();

    return PharmacyGarde(
      osmId: id,
      name: (json['name'] ?? json['nom_pharmacie'] ?? 'Pharmacie').toString(),
      city: city,
      address: json['address']?.toString(),
      phones: phones,
      lat: toDouble(json['latitude'] ?? json['lat']) ?? 0.0,
      lng: toDouble(json['longitude'] ?? json['lng']) ?? 0.0,
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      isOnDuty: json['est_garde'] == true || json['est_garde'] == 1 || json['isOnDuty'] == true,
      distanceKm: toDouble(json['distance']),
    );
  }

  factory PharmacyGarde.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final rawPhones = json['phones'];
    final phones = rawPhones is List ? rawPhones.map((e) => e.toString()).toList() : <String>[];

    return PharmacyGarde(
      osmId: json['osmId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pharmacie',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString(),
      phones: phones,
      lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      isOnDuty: json['isOnDuty'] == true || json['est_garde'] == true,
    );
  }

  /// Compatibilité avec les anciens écrans qui utilisent p['phone'], p['latitude'], etc.
  Map<String, dynamic> toLegacyMap() {
    return {
      'name': name,
      'address': address ?? '',
      'phone': phones.isNotEmpty ? phones.first : '',
      'phones': phones,
      'latitude': lat,
      'longitude': lng,
      'lat': lat,
      'lng': lng,
      'osmId': osmId,
      'sourceUrl': sourceUrl,
      'city': city,
    };
  }
}

class PharmacySearchResult {
  final String city;
  final String normalizedCity;
  final String status; // "ok" | "empty" | "unknown_city"
  final String message;
  final int count;
  final List<PharmacyGarde> pharmacies;
  final String fetchedAt;
  final String cache; // "hit" | "miss"

  /// Correction orthographique proposée par le serveur (« Vouliez-vous dire … ? »).
  final String? didYouMean;

  const PharmacySearchResult({
    required this.city,
    required this.normalizedCity,
    required this.status,
    required this.message,
    required this.count,
    required this.pharmacies,
    required this.fetchedAt,
    required this.cache,
    this.didYouMean,
  });

  factory PharmacySearchResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['pharmacies'] as List<dynamic>? ?? [];
    return PharmacySearchResult(
      city: json['city']?.toString() ?? '',
      normalizedCity: json['normalizedCity']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown_city',
      message: json['message']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      pharmacies: rawList.map((e) => PharmacyGarde.fromJson(e as Map<String, dynamic>)).toList(),
      fetchedAt: json['fetchedAt']?.toString() ?? '',
      cache: json['cache']?.toString() ?? 'miss',
      didYouMean: (json['didYouMean']?.toString() ?? '').trim().isEmpty ? null : json['didYouMean'].toString().trim(),
    );
  }
}

/// Normalise un texte pour une comparaison insensible aux accents et à la casse.
String normalizeSearchText(String value) {
  const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final idx = accents.indexOf(ch);
    buffer.write(idx >= 0 ? plain[idx] : ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class _Cached<T> {
  final T value;
  final DateTime at;
  _Cached(this.value) : at = DateTime.now();
  bool get isFresh => DateTime.now().difference(at) < PharmacyGardeService.cacheTtl;
}

class CityEntry {
  final String city;
  final String region;
  const CityEntry({required this.city, required this.region});

  factory CityEntry.fromJson(Map<String, dynamic> json) =>
      CityEntry(city: json['city']?.toString() ?? '', region: json['region']?.toString() ?? '');
}

// ============================================================================
// Service
// ============================================================================

/// Service d'accès à l'API Pharmacies Garde Cameroun.
///
/// Baseurl configuré via [PharmacyGardeService.baseUrl].
/// Par défaut pointe vers le serveur de production TAKYMED.
class PharmacyGardeService {
  // URL de base — à surcharger via variable d'environnement ou config au démarrage
  static String baseUrl = 'http://82.165.150.150:3500';

  static const Duration _timeout = Duration(seconds: 15);

  /// Durée de validité du cache mémoire (les pharmacies changent rarement ;
  /// une réouverture de l'écran doit être instantanée).
  static const Duration cacheTtl = Duration(minutes: 10);

  static final Map<String, _Cached<PharmacySearchResult>> _cityCache = {};
  static _Cached<List<CityEntry>>? _citiesCache;

  static Map<String, String> get _headers => const {'Accept': 'application/json', 'Content-Type': 'application/json'};

  /// Vide le cache (tirer-pour-rafraîchir).
  static void clearCache() {
    _cityCache.clear();
    _citiesCache = null;
  }

  /// Pré-remplit le cache (tests de widgets sans réseau).
  @visibleForTesting
  static void seedCache({List<CityEntry>? cities, Map<String, PharmacySearchResult>? byCity}) {
    if (cities != null) _citiesCache = _Cached(cities);
    byCity?.forEach((city, result) => _cityCache[normalizeSearchText(city)] = _Cached(result));
  }

  // ── Recherche de pharmacies par ville ────────────────────────────────────

  /// Recherche les pharmacies dans [city] via OpenStreetMap / Nominatim.
  ///
  /// Retourne un [PharmacySearchResult] avec status "ok", "empty" ou "unknown_city".
  /// Lève une [Exception] si le réseau est indisponible ou si le serveur renvoie une erreur.
  /// Les résultats « ok » sont mis en cache [cacheTtl] ; [force] ignore le cache.
  static Future<PharmacySearchResult> searchByCity(String city, {bool force = false}) async {
    final cacheKey = normalizeSearchText(city);
    final cached = _cityCache[cacheKey];
    if (!force && cached != null && cached.isFresh) return cached.value;

    final uri = Uri.parse('$baseUrl/api/v1/pharmacies?city=${Uri.encodeComponent(city.trim())}');

    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 404) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = PharmacySearchResult.fromJson(json);
        // On ne met en cache que les réponses stables (pas les « synchro en cours »).
        if (result.status == 'ok' || result.status == 'unknown_city') {
          _cityCache[cacheKey] = _Cached(result);
        }
        return result;
      }

      if (response.statusCode == 400) {
        throw Exception('Le nom de la ville est obligatoire.');
      }

      if (response.statusCode == 502) {
        throw Exception('Le service de pharmacies est momentanément indisponible.');
      }

      throw Exception('Erreur serveur (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Délai de connexion dépassé. Vérifiez votre connexion internet.');
    } on http.ClientException catch (e) {
      throw Exception('Impossible de joindre le serveur : $e');
    }
  }

  // ── Liste des villes ─────────────────────────────────────────────────────

  /// Retourne les villes camerounaises supportées.
  static Future<List<CityEntry>> getCities() async {
    final cached = _citiesCache;
    if (cached != null && cached.isFresh) return cached.value;

    final uri = Uri.parse('$baseUrl/api/v1/cities');

    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = json['cities'] as List<dynamic>? ?? [];
        final cities = rawList.map((e) => CityEntry.fromJson(e as Map<String, dynamic>)).toList();
        _citiesCache = _Cached(cities);
        return cities;
      }
      throw Exception('Impossible de récupérer la liste des villes.');
    } on TimeoutException {
      throw Exception('Délai de connexion dépassé.');
    } on http.ClientException catch (e) {
      throw Exception('Erreur réseau : $e');
    }
  }

  // ── Pharmacies à proximité (cache partagé entre les instances d'écran) ──

  static _Cached<Map<String, dynamic>>? _nearbyCache;
  static String? _nearbyCacheKey;

  /// Clé de cache : position arrondie à ~1 km (ou « none » sans position).
  static String nearbyKey(double? lat, double? lng) =>
      lat == null || lng == null ? 'none' : '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  static Map<String, dynamic>? cachedNearby(double? lat, double? lng) {
    final c = _nearbyCache;
    if (c == null || !c.isFresh || _nearbyCacheKey != nearbyKey(lat, lng)) return null;
    return c.value;
  }

  static void rememberNearby(double? lat, double? lng, Map<String, dynamic> data) {
    _nearbyCacheKey = nearbyKey(lat, lng);
    _nearbyCache = _Cached(data);
  }

  // ── Santé du service ─────────────────────────────────────────────────────

  /// Vérifie que le service est disponible. Retourne true si opérationnel.
  static Future<bool> isHealthy() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'), headers: _headers).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
