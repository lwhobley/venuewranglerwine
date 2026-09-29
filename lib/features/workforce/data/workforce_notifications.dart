import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/workforce_models.dart';
import 'workforce_repository.dart';

@pragma('vm:entry-point')
Future<void> workforceBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are displayed by Android; sensitive data stays in authenticated screens.
}

final workforceNotificationsProvider = Provider<WorkforceNotifications>((ref) {
  final service = WorkforceNotifications(ref.read(workforceRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

class WorkforceNotifications {
  WorkforceNotifications(this.repository);
  final WorkforceRepository repository;
  final local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  String? organization, venue;
  bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Firebase.apps.isNotEmpty;
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'workforce',
      'Schedule updates',
      channelDescription: 'Shift changes and reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  Future<bool> enable(
    String org,
    String venueId,
    void Function(String?) open,
  ) async {
    if (!supported) return false;
    organization = org;
    venue = venueId;
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => open(r.payload),
    );
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    Future<void> register(String token) async {
      if (organization != org || venue != venueId) return;
      await repository.send(
        org,
        venueId,
        repository.command(org, venueId, 'register_push', {
          'token': token,
          'platform': 'android',
        }),
      );
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await register(token);
    await _tokens?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _tokens = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(register(token).catchError((Object _) {}));
    });
    _foreground = FirebaseMessaging.onMessage.listen((m) {
      unawaited(
        local.show(
          id: (m.data['notification_id'] ?? m.messageId).hashCode & 0x7fffffff,
          title: m.notification?.title ?? 'Schedule update',
          body: m.notification?.body ?? 'Open your schedule to review.',
          notificationDetails: details,
          payload: m.data['shift_id'] as String?,
        ),
      );
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => open(m.data['shift_id'] as String?),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) open(initial.data['shift_id'] as String?);
    return true;
  }

  Future<void> reminders(
    List<WorkShift> shifts,
    int minutes,
    String zone,
  ) async {
    if (!supported || organization == null) return;
    await local.cancelAll();
    for (final shift in shifts.take(60)) {
      final when = shift.startsAt.subtract(Duration(minutes: minutes));
      if (!when.isAfter(DateTime.now().toUtc())) continue;
      await local.zonedSchedule(
        id: shift.id.hashCode & 0x7fffffff,
        title: 'Upcoming shift',
        body: 'Your ${shift.roleKey} shift starts in $minutes minutes.',
        scheduledDate: tz.TZDateTime.from(when, tz.getLocation(zone)),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: shift.id,
      );
    }
  }

  void dispose() {
    organization = null;
    venue = null;
    unawaited(_tokens?.cancel());
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
  }
}
