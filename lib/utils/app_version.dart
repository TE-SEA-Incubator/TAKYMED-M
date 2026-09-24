import 'package:package_info_plus/package_info_plus.dart';

/// Version affichée dans l'app (lue depuis pubspec / build natif).
class AppVersion {
  static PackageInfo? _cached;

  static Future<PackageInfo> load() async {
    _cached ??= await PackageInfo.fromPlatform();
    return _cached!;
  }

  static Future<String> label({String prefix = 'TAKYMED '}) async {
    final info = await load();
    return '${prefix}v${info.version}';
  }
}
