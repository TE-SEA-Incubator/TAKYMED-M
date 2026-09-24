/// Helpers partagés pour la recherche médicaments / pharmacies.
class MedHelpers {
  MedHelpers._();

  static int? parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Évite de charger des images base64 lourdes dans les listes.
  static String? photoForList(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image/') || trimmed.length > 512) return null;
    return trimmed;
  }

  static String formatDistance(dynamic distance) {
    if (distance == null) return '';
    if (distance is num) return '${distance.toStringAsFixed(distance is int ? 0 : 1)} km';
    return '$distance km';
  }

  /// Affichage court pour les listes (ex. « 850 m », « 2,3 km »).
  static String formatDistanceShort(dynamic distance) {
    if (distance == null) return '—';
    final km = distance is num ? distance.toDouble() : double.tryParse(distance.toString());
    if (km == null) return safeString(distance);
    if (km < 1) return '${(km * 1000).round()} m';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  /// Ville ou région — évite d'afficher l'adresse complète dans les listes.
  static String shortLocation(dynamic pharmacy) {
    final region = safeString(pharmacy['region']).trim();
    if (region.isNotEmpty) return region;

    final ville = safeString(pharmacy['ville']).trim();
    if (ville.isNotEmpty) return ville;

    final address = safeString(pharmacy['address']).trim();
    if (address.isEmpty) return 'Cameroun';

    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) return parts.last;
    if (address.length > 36) return '${address.substring(0, 33)}…';
    return address;
  }

  static String safeString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }
}
