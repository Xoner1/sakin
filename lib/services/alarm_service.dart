import 'package:adhan/adhan.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';
import '../models/location_info.dart';
import '../models/prayer_notification_settings.dart';

class PrayerAlarmScheduler {
  static const String _settingsBoxName = 'settings';
  static const String _lastScheduledKey = 'last_scheduled_date';

  /// Schedules prayer alarms/notifications for the next 7 days.
  static Future<void> scheduleSevenDays() async {
    final box = await Hive.openBox(_settingsBoxName);
    final locationData = box.get('cached_location');
    final settingsData = box.get('notification_settings');

    if (locationData == null) {
      debugPrint('⚠️ Cannot schedule: No location data found.');
      return;
    }

    final location =
        LocationInfo.fromJson(Map<String, dynamic>.from(locationData));
    final settings = settingsData != null
        ? PrayerNotificationSettings.fromJson(
            Map<String, dynamic>.from(settingsData))
        : const PrayerNotificationSettings();

    final coordinates = Coordinates(location.latitude, location.longitude);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;

    debugPrint('⏳ Scheduling prayers for 7 days starting from today...');

    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      final dateComponents = DateComponents.from(date);
      final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

      await _scheduleDayPrayers(prayerTimes, settings, i);
    }

    await box.put(_lastScheduledKey, DateTime.now().toIso8601String());
    debugPrint('✅ Successfully scheduled 35 potential prayer alarms.');
  }

  static Future<void> _scheduleDayPrayers(PrayerTimes prayerTimes,
      PrayerNotificationSettings settings, int dayOffset) async {
    final prayers = {
      'Fajr': prayerTimes.fajr,
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };

    int baseId = dayOffset * 10; // Unique ID space for each day

    prayers.forEach((name, time) async {
      bool isEnabled = false;
      int prayerId = baseId;

      switch (name) {
        case 'Fajr':
          isEnabled = settings.fajrEnabled;
          prayerId += 0;
          break;
        case 'Dhuhr':
          isEnabled = settings.dhuhrEnabled;
          prayerId += 1;
          break;
        case 'Asr':
          isEnabled = settings.asrEnabled;
          prayerId += 2;
          break;
        case 'Maghrib':
          isEnabled = settings.maghribEnabled;
          prayerId += 3;
          break;
        case 'Isha':
          isEnabled = settings.ishaEnabled;
          prayerId += 4;
          break;
      }

      if (isEnabled && time.isAfter(DateTime.now())) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _scheduleAndroidAlarm(prayerId, name, time);
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _scheduleIOSNotification(prayerId, name, time);
        }
      }
    });
  }

  static Future<void> _scheduleAndroidAlarm(
      int id, String prayerName, DateTime time) async {
    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      adhanAlarmCallback, // Reusing existing callback from notification_service.dart
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      params: {'prayerName': prayerName},
    );
  }

  static Future<void> _scheduleIOSNotification(
      int id, String prayerName, DateTime time) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // iOS specific details with 30s adhan sound
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'adhan.caf', // iOS requires .caf or .wav usually if custom
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(iOS: iosDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '🕌 حان وقت صلاة $prayerName',
      'اللهم إني أسألك الثبات في الأمر والعزيمة على الرشد',
      tz.TZDateTime.from(time, tz.local),
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Checks if the last scheduling was more than 7 days ago.
  static Future<void> checkAndNotifyTTL() async {
    final box = await Hive.openBox(_settingsBoxName);
    final lastScheduledStr = box.get(_lastScheduledKey);

    if (lastScheduledStr != null) {
      final lastScheduled = DateTime.parse(lastScheduledStr);
      final diff = DateTime.now().difference(lastScheduled).inDays;

      if (diff >= 7) {
        await NotificationService.showNotification(
          '⚠️ تحديث مطلوب',
          'يرجى فتح التطبيق لتحديث مواقيت الصلاة للأسبوع القادم.',
        );
      }
    }
  }
}
