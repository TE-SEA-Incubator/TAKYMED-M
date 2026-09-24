import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum NativeNotificationKind { reminder, message }

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = 'takymed_reminders';
  static const String messageChannelId = 'takymed_messages';

  static bool _initialized = false;
  static bool _timezonesLoaded = false;

  /// Fuseau par défaut tant que le compte n'a pas fourni le sien.
  static const String defaultTimezone = 'Africa/Douala';
  static String _currentTimezone = defaultTimezone;

  static String get currentTimezone => _currentTimezone;

  static void _ensureTimezones() {
    if (_timezonesLoaded) return;
    tz.initializeTimeZones();
    _timezonesLoaded = true;
  }

  /// Fuseau local garanti : `tz.local` lève une erreur tant qu'aucun fuseau n'a
  /// été fixé (premier rendu avant la fin de [applyTimezone]) ; on retombe alors
  /// sur le fuseau par défaut plutôt que de planter l'écran.
  static tz.Location get localLocation {
    _ensureTimezones();
    try {
      return tz.local;
    } catch (_) {
      tz.setLocalLocation(tz.getLocation(defaultTimezone));
      return tz.local;
    }
  }

  /// Aligne le fuseau local des notifications sur celui du pays de l'utilisateur
  /// (valeur `timezone` renvoyée par l'API). Fuseau invalide/absent → défaut.
  static Future<void> applyTimezone(String? ianaTimezone) async {
    _ensureTimezones();
    final candidate = (ianaTimezone ?? '').trim();
    try {
      final location = tz.getLocation(candidate.isEmpty ? defaultTimezone : candidate);
      tz.setLocalLocation(location);
      _currentTimezone = location.name;
    } catch (_) {
      tz.setLocalLocation(tz.getLocation(defaultTimezone));
      _currentTimezone = defaultTimezone;
    }
    debugPrint('🕐 Fuseau horaire des rappels : $_currentTimezone');
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _ensureTimezones();
    tz.setLocalLocation(tz.getLocation(_currentTimezone));

    // Android : utiliser l'icône launcher comme icône de notification
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tap: ${response.payload}');
      },
    );

    if (Platform.isAndroid) {
      final android = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Demander la permission de notification (Android 13+)
      await android?.requestNotificationsPermission();

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          reminderChannelId,
          'Rappels médicaments',
          description: 'Rappels natifs pour vos prises de médicaments',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          messageChannelId,
          'Messages TAKYMED',
          description: 'Messages et alertes de l\'application',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notifGranted = await android?.requestNotificationsPermission() ?? true;
      await android?.requestExactAlarmsPermission();
      return notifGranted;
    }

    if (Platform.isIOS) {
      final ios = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    return true;
  }

  static NotificationDetails _details(NativeNotificationKind kind, {String body = ''}) {
    if (kind == NativeNotificationKind.reminder) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          'Rappels médicaments',
          channelDescription: 'Rappels natifs pour vos prises de médicaments',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          ticker: 'Rappel TAKYMED',
          icon: '@mipmap/launcher_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: BigTextStyleInformation(body),
          ongoing: false,
          autoCancel: true,
          playSound: true,
          enableVibration: true,
          // Heads-up notification (bandeau en haut de l'écran)
          channelShowBadge: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'TAKYMED_REMINDER',
        ),
      );
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        messageChannelId,
        'Messages TAKYMED',
        channelDescription: 'Messages et alertes de l\'application',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        icon: '@mipmap/launcher_icon',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: BigTextStyleInformation(body),
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        categoryIdentifier: 'TAKYMED_MESSAGE',
      ),
    );
  }

  static Future<void> showNativeNotification({
    required int id,
    required String title,
    required String body,
    NativeNotificationKind kind = NativeNotificationKind.message,
    String? payload,
  }) async {
    await initialize();
    final details = _details(kind, body: body);

    await flutterLocalNotificationsPlugin.show(id, title, body, details, payload: payload);
  }

  static Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await initialize();
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      _details(NativeNotificationKind.reminder, body: body),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  static NativeNotificationKind kindFromPayload(String? payload, {String? typeHint}) {
    if (typeHint != null) {
      final t = typeHint.toLowerCase();
      if (t.contains('reminder') || t.contains('rappel') || t.contains('dose')) {
        return NativeNotificationKind.reminder;
      }
    }
    if (payload == null || payload.isEmpty) return NativeNotificationKind.message;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final type = map['type']?.toString().toLowerCase() ?? '';
      if (type.contains('reminder') || type.contains('dose')) {
        return NativeNotificationKind.reminder;
      }
    } catch (_) {}
    return NativeNotificationKind.message;
  }
}
