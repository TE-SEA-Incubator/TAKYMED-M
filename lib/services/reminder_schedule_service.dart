
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Planifie les rappels de prises en notifications natives locales (fonctionne app fermée).
class ReminderScheduleService {
  static const _syncKey = 'takymed_reminder_sync_at';
  static final Set<int> _scheduledDoseIds = {};

  static Future<void> syncFromServer(ApiService api, int userId) async {
    try {
      final data = await api.getDashboard(userId);
      final doses = (data['doses'] as List<dynamic>?) ?? [];

      for (final id in _scheduledDoseIds) {
        await NotificationService.cancelNotification(id);
      }
      _scheduledDoseIds.clear();

      final now = DateTime.now();
      final horizon = now.add(const Duration(days: 14));
      var scheduled = 0;

      for (final raw in doses) {
        if (raw is! Map) continue;
        if (raw['statusTaken'] == true || raw['statusTaken'] == 1) continue;

        final scheduledAt = raw['scheduledAt']?.toString();
        if (scheduledAt == null) continue;

        final dt = DateTime.tryParse(scheduledAt);
        if (dt == null || dt.isBefore(now) || dt.isAfter(horizon)) continue;

        final doseId = (raw['id'] as num?)?.toInt();
        if (doseId == null) continue;

        final medName = raw['medicationName']?.toString() ?? 'Médicament';
        final dose = raw['dose']?.toString() ?? '';
        final unit = raw['unit']?.toString() ?? '';
        final client = raw['clientName']?.toString() ?? '';

        await NotificationService.scheduleReminderNotification(
          id: doseId,
          title: '💊 Rappel TAKYMED',
          body: client.isNotEmpty
              ? '$client — $medName : $dose $unit'.trim()
              : 'Il est l\'heure de prendre $medName ($dose $unit)'.trim(),
          scheduledDate: dt,
          payload: '{"type":"reminder","doseId":$doseId}',
        );
        _scheduledDoseIds.add(doseId);
        scheduled++;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncKey, DateTime.now().toIso8601String());
      // ignore: avoid_print
      print('📅 $scheduled rappels natifs planifiés');
    } catch (e) {
      // ignore: avoid_print
      print('ReminderScheduleService sync error: $e');
    }
  }
}
