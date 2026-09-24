/// Normalisation téléphone Cameroun — alignée sur le serveur (commercialClientService).
class PhoneUtils {
  PhoneUtils._();

  static String normalizeCameroon(String raw, {String dialCode = '+237'}) {
    var p = raw.replaceAll(RegExp(r'[\s\-().]'), '').trim();
    if (p.isEmpty) return '';

    final dc = dialCode.startsWith('+') ? dialCode : '+$dialCode';

    while (p.startsWith('$dc${dc.substring(1)}')) {
      p = '$dc${p.substring(dc.length + dc.length - 1)}';
    }

    if (RegExp(r'^\+2376\d{8}$').hasMatch(p)) return p;

    if (p.startsWith('2376')) {
      p = '+237${p.substring(3)}';
      if (RegExp(r'^\+2376\d{8}$').hasMatch(p)) return p;
    }

    if (p.startsWith(dc)) {
      final local = p.substring(dc.length).replaceFirst(RegExp(r'^0'), '');
      if (RegExp(r'^6\d{8}$').hasMatch(local)) return '$dc$local';
    }

    final local = p.replaceFirst(RegExp(r'^0'), '');
    if (RegExp(r'^6\d{8}$').hasMatch(local)) return '$dc$local';

    if (p.startsWith('+')) return p;
    return '$dc$p';
  }
}
