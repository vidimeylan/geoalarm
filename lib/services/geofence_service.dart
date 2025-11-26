import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../models/alarm.dart';
import '../screens/alarm/alarm_dismissal_screen.dart';
import '../main.dart' show navigatorKey;
import 'alarm_api_service.dart';
import 'location_service.dart';

class GeofenceService {
  GeofenceService._private();
  static final GeofenceService _instance = GeofenceService._private();
  factory GeofenceService() => _instance;

  final LocationService _locationService = LocationService();
  final AlarmApiService _api = AlarmApiService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription? _posSub;
  final Set<String> _alreadyTriggered = {};
  Timer? _alertTimer;
  bool _isAlerting = false;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  Future<void> startMonitoring() async {
    await init();
    if (_posSub != null) return; // already running
    
    print('[GeofenceService] Starting location monitoring...');
    
    // Ensure we have location permission before subscribing
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('[GeofenceService] Location permission denied ($permission). Monitoring not started.');
      return;
    }

    _posSub = _locationService.getPositionStream().listen((pos) async {
      try {
        // Load alarms every time (so new alarms are detected)
        List<Alarm> activeAlarms = [];
        try {
          final alarms = await _api.fetchAlarms();
          activeAlarms = alarms.where((a) => a.isActive).toList();
          print('[GeofenceService] Loaded ${activeAlarms.length} active alarms');
        } catch (e) {
          print('[GeofenceService] Error fetching alarms: $e');
        }

        print('[GeofenceService] Current position: ${pos.latitude}, ${pos.longitude}');
        
        for (final alarm in activeAlarms) {
          if (_alreadyTriggered.contains(alarm.id)) {
            print('[GeofenceService] Alarm ${alarm.id} already triggered, skipping');
            continue;
          }
          
          final distance = _locationService.getDistance(pos.latitude, pos.longitude, alarm.lat, alarm.lon);
          print('[GeofenceService] Alarm "${alarm.label}" - Distance: ${distance.toStringAsFixed(2)}m, Radius: ${alarm.radius}m');
          
          if (distance <= alarm.radius) {
            print('[GeofenceService] ✅ TRIGGERED: "${alarm.label}" (${distance.toStringAsFixed(2)}m <= ${alarm.radius}m)');
            _alreadyTriggered.add(alarm.id);
            _triggerAlarm(alarm);
          }
        }
      } catch (e) {
        print('[GeofenceService] Error in position listener: $e');
      }
    }, onError: (error) {
      // Handle errors from the location stream (e.g., permission denied at runtime)
      print('[GeofenceService] Location stream error: $error');
      if (error is Exception && error.toString().toLowerCase().contains('permission')) {
        // Stop monitoring if permissions revoked
        stopMonitoring();
      }
    });
    
    print('[GeofenceService] Location monitoring started');
  }

  Future<void> stopMonitoring() async {
    await _posSub?.cancel();
    _posSub = null;
    _alreadyTriggered.clear();
    _stopAlarmFeedback();
  }

  void stopAlarmFeedback() {
    _stopAlarmFeedback();
  }

  Future<void> _triggerAlarm(Alarm alarm) async {
    print('[GeofenceService] 🔔 Triggering alarm for: "${alarm.label}"');
    
    // Vibrate briefly
    try {
      HapticFeedback.heavyImpact();
      print('[GeofenceService] Haptic feedback triggered');
    } catch (e) {
      print('[GeofenceService] Haptic feedback error: $e');
    }

    // Try to navigate to alarm dismissal screen immediately
    try {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmDismissalScreen(alarm: alarm),
          fullscreenDialog: true,
        ),
      );
      print('[GeofenceService] ✅ Navigated to alarm dismissal screen');
    } catch (e) {
      print('[GeofenceService] ❌ Error navigating to dismissal screen: $e');
    }

    // Show persistent notification that cannot be dismissed
    const androidDetails = AndroidNotificationDetails(
      'geoalarm_channel',
      'GeoAlarm',
      channelDescription: 'Notifikasi alarm saat memasuki area tujuan',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ongoing: true, // Makes notification non-dismissible
      autoCancel: false, // Prevents auto-dismissal
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _notifications.show(
        alarm.id.hashCode,
        '🚨 ALARM: ${alarm.label}',
        'Anda memasuki radius ${alarm.radius} meter! Tekan untuk mematikan alarm.',
        details,
        payload: alarm.id, // This will trigger navigation when notification is tapped
      );
      print('[GeofenceService] ✅ Persistent notification shown for alarm: "${alarm.label}"');
    } catch (e) {
      print('[GeofenceService] ❌ Error showing notification: $e');
    }

    _startAlarmFeedback();
  }

  void _startAlarmFeedback() {
    if (_isAlerting) return;
    _isAlerting = true;

    try {
      FlutterRingtonePlayer().playAlarm(volume: 1.0, looping: true, asAlarm: true);
      print('[GeofenceService] 🔊 Alarm sound started');
    } catch (e) {
      print('[GeofenceService] ❌ Unable to play alarm sound: $e');
    }

    Vibration.hasVibrator().then((hasVibration) {
      if (hasVibration == true) {
        Vibration.vibrate(pattern: [0, 600, 200, 600], repeat: 1);
        print('[GeofenceService] 📳 Vibration pattern started');
      }
    }).catchError((e) {
      print('[GeofenceService] ❌ Vibration error: $e');
    });

    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 30), _stopAlarmFeedback);
  }

  void _stopAlarmFeedback() {
    if (!_isAlerting) return;
    _alertTimer?.cancel();
    _alertTimer = null;

    try {
      FlutterRingtonePlayer().stop();
      print('[GeofenceService] 🔇 Alarm sound stopped');
    } catch (e) {
      print('[GeofenceService] ❌ Error stopping alarm sound: $e');
    }

    Vibration.cancel().catchError((_) {});

    // Cancel the persistent notification
    _notifications.cancelAll();
    print('[GeofenceService] 🔔 Alarm notification cancelled');

    _isAlerting = false;
  }
}
