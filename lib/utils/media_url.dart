import '../services/api_service.dart';

/// Résout les URLs d'images médicaments renvoyées par l'API.
/// L'API peut renvoyer : URL absolue, chemin `/uploads/...`, ou data-URI base64.
class MediaUrl {
  MediaUrl._();

  static String get _origin => ApiService.serverOrigin;

  static bool isValid(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image/') ||
        trimmed.startsWith('/uploads/') ||
        trimmed.startsWith('uploads/');
  }

  static String resolve(String? url) {
    if (!isValid(url)) return '';
    final trimmed = url!.trim();

    if (trimmed.startsWith('data:image/') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '$_origin$trimmed';
    }

    return '$_origin/$trimmed';
  }
}
