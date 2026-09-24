
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'reminder_schedule_service.dart';

class PushService {
  static const _deviceIdKey = 'takymed_device_id';
  static const _userIdKey = 'takymed_user_id';
  static const _shownIdsKey = 'takymed_shown_notif_ids';
  static Timer? _pollTimer;
  static String? _lastPollSince;

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'mobile-${DateTime.now().millisecondsSinceEpoch}-${Platform.operatingSystem}';
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  static Future<void> persistUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<void> registerDevice(ApiService api, int userId) async {
    await persistUserId(userId);
    final deviceId = await _getOrCreateDeviceId();
    await api.registerDevice(
      userId,
      Platform.isIOS ? 'ios' : 'android',
      deviceId,
      deviceLabel: '${Platform.operatingSystem} device',
    );
  }

  static Future<void> startPolling(ApiService api, int userId) async {
    _pollTimer?.cancel();
    // Poll immédiat au démarrage, puis toutes les 15 secondes
    await _pollAll(api, userId);
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _pollAll(api, userId);
    });
    await ReminderScheduleService.syncFromServer(api, userId);
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<Set<int>> _loadShownIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_shownIdsKey) ?? [];
    return raw.map((e) => int.tryParse(e)).whereType<int>().toSet();
  }

  static Future<void> _saveShownIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = ids.toList()..sort();
    while (trimmed.length > 200) {
      trimmed.removeAt(0);
    }
    await prefs.setStringList(_shownIdsKey, trimmed.map((e) => e.toString()).toList());
  }

  static Future<void> _pollAll(ApiService api, int userId) async {
    await _pollPendingPush(api, userId);
    await _pollInAppMessages(api, userId);
  }

  static Future<void> _pollPendingPush(ApiService api, int userId) async {
    try {
      final pending = await api.getPendingPushNotifications(userId, since: _lastPollSince);
      if (pending.isEmpty) return;

      final ids = <int>[];
      for (final item in pending) {
        final id = (item['id'] as num?)?.toInt();
        if (id == null) continue;
        ids.add(id);

        final title = item['title']?.toString() ?? 'TAKYMED';
        final body = item['body']?.toString() ?? '';
        final payload = item['payload']?.toString();
        final type = item['type']?.toString();

        await NotificationService.showNativeNotification(
          id: id,
          title: title,
          body: body,
          kind: NotificationService.kindFromPayload(payload, typeHint: type),
          payload: payload,
        );
      }

      if (ids.isNotEmpty) {
        await api.ackPushNotifications(userId, ids);
        _lastPollSince = DateTime.now().toUtc().toIso8601String();
      }
    } catch (e) {
      debugPrint('Push poll error: $e');
    }
  }

  static Future<void> _pollInAppMessages(ApiService api, int userId) async {
    try {
      final response = await api.getNotifications(userId);
      final list = (response['notifications'] as List<dynamic>?) ?? [];
      final shown = await _loadShownIds();
      final newShown = Set<int>.from(shown);
      var displayed = false;

      for (final item in list) {
        if (item is! Map) continue;
        if (item['isRead'] == 1 || item['isRead'] == true) continue;

        final id = (item['id'] as num?)?.toInt();
        if (id == null || shown.contains(id)) continue;

        final type = item['type']?.toString() ?? 'general';
        final title = item['title']?.toString() ?? item['titre']?.toString() ?? 'Message TAKYMED';
        final body = item['content']?.toString() ?? item['contenu']?.toString() ?? '';

        await NotificationService.showNativeNotification(
          id: 100000 + id,
          title: title,
          body: body,
          kind: NotificationService.kindFromPayload(null, typeHint: type),
          payload: jsonEncode({'type': type, 'notificationId': id}),
        );
        newShown.add(id);
        displayed = true;
      }

      if (displayed) {
        await _saveShownIds(newShown);
      }
    } catch (e) {
      debugPrint('Message poll error: $e');
    }
  }

  static Future<void> syncReminders(ApiService api, int userId) async {
    await ReminderScheduleService.syncFromServer(api, userId);
  }

  static Future<bool> requestPermission() async {
    return NotificationService.requestPermissions();
  }
}
