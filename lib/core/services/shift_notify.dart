import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/shift.dart';

class ShiftNotify {
  ShiftNotify._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static var enabled = false;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    _useDeviceOffset();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    enabled = true;
  }

  static void _useDeviceOffset() {
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
        tz.setLocalLocation(location);
        return;
      }
    }
  }

  static Future<void> sync(List<Schedule> schedules) async {
    if (!enabled) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    var id = 1;
    for (final schedule in schedules) {
      if (schedule.remindMinutes <= 0) continue;
      for (var i = 0; i < 21; i++) {
        final day = dateOnly(now).add(Duration(days: i));
        final slot = slotOn(schedule, day);
        if (slot.before || slot.isOff || slot.start.isEmpty) continue;
        final parts = slot.start.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        final start = DateTime(day.year, day.month, day.day, hour, minute);
        final when = start.subtract(Duration(minutes: schedule.remindMinutes));
        if (!when.isAfter(now)) continue;
        final scheduled = tz.TZDateTime.local(when.year, when.month, when.day, when.hour, when.minute);
        await _plugin.zonedSchedule(
          id++,
          '${schedule.name} · ${kindLabel(slot.kind)}',
          slot.hours,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails('shifts', 'Shift reminders', channelDescription: 'A nudge before a shift starts'),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        if (id > 40) return;
      }
    }
  }
}
