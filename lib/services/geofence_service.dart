import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/notification_icon_data.dart';
import 'package:geofence_foreground_service/models/zone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlng/latlng.dart';
import 'package:vibration/vibration.dart';

import '../models/alarm.dart';
import '../screens/alarm/alarm_dismissal_screen.dart';
import '../main.dart' show navigatorKey;
import 'alarm_api_service.dart';
import 'location_service.dart';

/// Background callback dispatcher for geofence events
@pragma('vm:entry-point')
void geofenceCallbackDispatcher() {
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneId, triggerType) async {
      log('Geofence triggered: $zoneId, type: $triggerType', name: 'GeofenceService');

      if (triggerType == GeofenceEventType.enter) {
        try {
          // Since we can't directly call Flutter UI from background isolate,
          // we'll use a notification with payload to wake up the main app
          log('BACKGROUND ALARM TRIGGERED: $zoneId', name: 'GeofenceService');

          // The notification will be handled by the main app's notification tap handler
          // This will bring the app to foreground and trigger the alarm
        } catch (e) {
          log('Error in geofence callback: $e', name: 'GeofenceService');
        }
      }

      return true;
    },
  );
}

class GeofenceService {
  GeofenceService._private();
  static final GeofenceService _instance = GeofenceService._private();
  factory GeofenceService() => _instance;

  final AlarmApiService _api = AlarmApiService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final LocationService _locationService = LocationService();

  final Set<String> _alreadyTriggered = {};
  Timer? _alertTimer;
  bool _isAlerting = false;
  bool _initialized = false;
  bool _serviceStarted = false;

  StreamSubscription<Position>? _foregroundSubscription;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  Future<void> startMonitoring() async {
    await init();
    if (_serviceStarted && _foregroundSubscription != null) return;

    print('[GeofenceService] Starting hybrid geofencing (background + foreground)...');

    // Start background geofencing service
    try {
      _serviceStarted = await GeofenceForegroundService().startGeofencingService(
        notificationChannelId: 'geoalarm_geofencing_channel',
        contentTitle: 'GeoAlarm - Monitoring Location',
        contentText: 'App is monitoring your location for active alarms',
        serviceId: 525600,
        callbackDispatcher: geofenceCallbackDispatcher,
        isInDebugMode: false, // Set to false for production
        notificationIconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      );

      if (_serviceStarted) {
        print('[GeofenceService] ✅ Background geofencing service started');
        await _setupActiveGeofences();
      }
    } catch (e) {
      print('[GeofenceService] ❌ Error starting background service: $e');
    }

    // Start foreground location monitoring for more responsive detection
    try {
      await _startForegroundMonitoring();
      print('[GeofenceService] ✅ Foreground monitoring started');
    } catch (e) {
      print('[GeofenceService] ❌ Error starting foreground monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      // Stop foreground monitoring
      await _foregroundSubscription?.cancel();
      _foregroundSubscription = null;

      // Clear all geofences
      await GeofenceForegroundService().removeAllGeoFences();
      _alreadyTriggered.clear();
      _stopAlarmFeedback();
      _serviceStarted = false;
      print('[GeofenceService] ✅ Hybrid geofencing stopped');
    } catch (e) {
      print('[GeofenceService] ❌ Error stopping geofencing: $e');
    }
  }

  Future<void> _startForegroundMonitoring() async {
    if (_foregroundSubscription != null) return;

    // Request location permission if needed
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('[GeofenceService] Location permission denied for foreground monitoring');
      return;
    }

    _foregroundSubscription = _locationService.getPositionStream().listen((pos) async {
      try {
        // Load alarms every time (so new alarms are detected)
        List<Alarm> activeAlarms = [];
        try {
          final alarms = await _api.fetchAlarms();
          activeAlarms = alarms.where((a) => a.isActive).toList();
        } catch (e) {
          print('[GeofenceService] Error fetching alarms: $e');
          return;
        }

        for (final alarm in activeAlarms) {
          if (_alreadyTriggered.contains(alarm.id)) {
            continue;
          }

          final distance = _locationService.getDistance(pos.latitude, pos.longitude, alarm.lat, alarm.lon);

          if (distance <= alarm.radius) {
            print('[GeofenceService] ✅ FOREGROUND TRIGGERED: "${alarm.label}" (${distance.toStringAsFixed(2)}m <= ${alarm.radius}m)');
            _alreadyTriggered.add(alarm.id);
            _triggerAlarm(alarm);
          }
        }
      } catch (e) {
        print('[GeofenceService] Error in foreground position listener: $e');
      }
    }, onError: (error) {
      print('[GeofenceService] Foreground location stream error: $error');
    });
  }

  Future<void> _setupActiveGeofences() async {
    try {
      // Clear existing geofences
      await GeofenceForegroundService().removeAllGeoFences();

      // Fetch active alarms
      final alarms = await _api.fetchAlarms();
      final activeAlarms = alarms.where((a) => a.isActive).toList();

      print('[GeofenceService] Setting up ${activeAlarms.length} active geofences');

      for (final alarm in activeAlarms) {
        final zone = Zone(
          id: alarm.id,
          radius: alarm.radius.toDouble(),
          coordinates: [LatLng.degree(alarm.lat, alarm.lon)],
          triggers: [GeofenceEventType.enter],
          notificationResponsivenessMs: 5000, // 5 seconds
        );

        final success = await GeofenceForegroundService().addGeofenceZone(zone: zone);
        if (success) {
          print('[GeofenceService] ✅ Added geofence: ${alarm.label} (${alarm.lat}, ${alarm.lon}, ${alarm.radius}m)');
        } else {
          print('[GeofenceService] ❌ Failed to add geofence: ${alarm.label}');
        }
      }
    } catch (e) {
      print('[GeofenceService] ❌ Error setting up geofences: $e');
    }
  }

  void stopAlarmFeedback() {
    _stopAlarmFeedback();
  }

  Future<void> refreshGeofences() async {
    if (!_serviceStarted) return;
    print('[GeofenceService] 🔄 Refreshing geofences...');
    await _setupActiveGeofences();
    print('[GeofenceService] ✅ Geofences refreshed');
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
