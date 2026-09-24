import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Helpers d'affichage autour des fuseaux IANA (heure locale, décalage UTC).
class TimezoneUtils {
  TimezoneUtils._();

  static bool _loaded = false;

  static void ensureLoaded() {
    if (_loaded) return;
    tzdata.initializeTimeZones();
    _loaded = true;
  }

  static tz.Location? location(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    ensureLoaded();
    try {
      return tz.getLocation(name.trim());
    } catch (_) {
      return null;
    }
  }

  /// Heure locale « HH:mm » dans le fuseau donné (ou `--:--` si inconnu).
  static String localTime(String? name, {DateTime? at}) {
    final loc = location(name);
    if (loc == null) return '--:--';
    final now = tz.TZDateTime.from(at ?? DateTime.now(), loc);
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Décalage UTC lisible, ex. « UTC+1 » ou « UTC−3:30 ».
  static String utcOffset(String? name, {DateTime? at}) {
    final loc = location(name);
    if (loc == null) return '';
    final now = tz.TZDateTime.from(at ?? DateTime.now(), loc);
    final minutes = now.timeZoneOffset.inMinutes;
    final sign = minutes < 0 ? '−' : '+';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    return 'UTC$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
  }

  /// Libellé court : « Africa/Douala » → « Douala ».
  static String cityLabel(String? name) {
    if (name == null || name.isEmpty) return '—';
    final last = name.split('/').last;
    return last.replaceAll('_', ' ');
  }
}
