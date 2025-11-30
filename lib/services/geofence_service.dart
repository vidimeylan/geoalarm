import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/notification_icon_data.dart';
import 'package:geofence_foreground_service/models/zone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlng/latlng.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/alarm.dart';
import '../main.dart' show navigatorKey; 
import '../screens/alarm/alarm_dismissal_screen.dart'; 
import 'alarm_repository.dart';
import 'location_service.dart';

// --- KONFIGURASI ---
const int kHybridBufferRadius = 500; 
const String kBgChannelId = 'siagaturun_bg_channel'; // Channel ID
const String kBgChannelName = 'SiagaTurun Geoalarm Service';
// Ganti nama icon di sini agar konsisten
const String kIconName = '@mipmap/launcher_icon'; 

// ==============================================================================
// 1. BACKGROUND SERVICE ENTRY POINT 
// ==============================================================================
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. Setup Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kBgChannelId,
    kBgChannelName,
    description: 'Service pemantau lokasi',
    importance: Importance.low, 
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  StreamSubscription<Position>? positionStream;
  Timer? heartbeatTimer; // Timer untuk polling ringan
  final LocationService locationService = LocationService();
  final AlarmRepository repo = AlarmRepository();
  
  // Variable flag biar gak start double
  bool isPrecisionMode = false;

  // 2. Set Status Awal: STANDBY
  if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          888,
          'GeoAlarm: Standby',
          'Menunggu masuk area tujuan.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              kBgChannelId,
              kBgChannelName,
              icon: kIconName,
              ongoing: true,
              showWhen: false,
            ),
          ),
        );
      }
  }

  // --- FUNGSI START TRACKING (PRECISION MODE) ---
  // Dipisahkan agar bisa dipanggil langsung dari heartbeat (isolate yang sama)
  Future<void> startPrecisionTracking() async {
    if (isPrecisionMode) return; // Cegah double start
    isPrecisionMode = true;

    print('[BgService] 🚀 SWITCHING TO PRECISION MODE...');
    
    // UBAH Notifikasi jadi "Mode Presisi"
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          888,
          'Mode Presisi Aktif',
          'Jarak dekat! Memantau meter-per-meter...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              kBgChannelId,
              kBgChannelName,
              icon: kIconName,
              ongoing: true,
              importance: Importance.high, 
              color: Colors.red,
            ),
          ),
        );
      }
    }

    await positionStream?.cancel();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, 
      ),
    ).listen((pos) async {
      try {
        List<Alarm> activeAlarms = [];
        try {
           final alarms = await repo.fetchAlarms();
           activeAlarms = alarms.where((a) => a.isActive).toList();
        } catch (e) {
           print('[BgService] Fetch Error: $e'); // LOG ERRORNYA
           return; 
        }

        bool closeToAny = false;

        for (final alarm in activeAlarms) {
          final distance = locationService.getDistance(pos.latitude, pos.longitude, alarm.lat, alarm.lon);
          
          if (distance <= alarm.radius) {
            print('[BgService] ALARM HIT!');
            _triggerBackgroundAlarm(alarm);
            
            positionStream?.cancel();
            isPrecisionMode = false; // Reset flag agar heartbeat jalan lagi
            
            // Kembalikan notifikasi service ke "Standby"
            if (service is AndroidServiceInstance) {
                flutterLocalNotificationsPlugin.show(
                  888,
                  'GeoAlarm: Standby',
                  'Menunggu masuk area tujuan.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      kBgChannelId,
                      kBgChannelName,
                      icon: kIconName,
                      ongoing: true,
                      showWhen: false,
                    ),
                  ),
                );
            }
            return;
          }
          
          if (distance < (alarm.radius + kHybridBufferRadius)) {
            closeToAny = true;
          }
        }
        
        if (!closeToAny && activeAlarms.isNotEmpty) {
            print('[BgService] Menjauh. Kembali ke Standby.');
            positionStream?.cancel(); 
            isPrecisionMode = false; // Reset flag
            
            // Balik ke notif standby
            if (service is AndroidServiceInstance) {
                flutterLocalNotificationsPlugin.show(
                  888,
                  'GeoAlarm: Standby',
                  'Menunggu masuk area tujuan.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      kBgChannelId,
                      kBgChannelName,
                      icon: kIconName,
                      ongoing: true,
                    ),
                  ),
                );
            }
        }
      } catch (e) {
        print('[BgService] Stream Error: $e');
      }
    });
  }

  // --- FUNGSI HEARTBEAT (POLITE POLLING) ---
  // Cek lokasi setiap 15 detik sebagai backup jika Geofence macet
  heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
    print('[BgService] Heartbeat: Running');
    if (isPrecisionMode) return; // Kalau sudah presisi, jangan cek lagi

    try {
      // Cek lokasi sekilas (Low Accuracy gapapa buat hemat baterai)
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      
      // Cek apakah dekat dengan alarm manapun?
      final alarms = await repo.fetchAlarms(); // Pastikan repo aman dari error
      final activeAlarms = alarms.where((a) => a.isActive).toList();
      print("[BgService-Heartbeat] Alarm: $alarms");
      print("[BgService-Heartbeat] Active Alarm: $activeAlarms");
      bool isClose = false;
      for (final alarm in activeAlarms) {
         double dist = locationService.getDistance(pos.latitude, pos.longitude, alarm.lat, alarm.lon);        
         print('[BgService] Heartbeat: Jarak: $dist');
         // Kalau masuk buffer, paksa start tracking
         if (dist < (alarm.radius + kHybridBufferRadius)) {
            isClose = true;
            break;
         }
      }

      if (isClose) {
         print('[BgService] Heartbeat: Dekat target! Memaksa Mode Presisi.');
         // Panggil langsung fungsi lokal, JANGAN pakai invoke jika di isolate yang sama
         startPrecisionTracking();
      }
    } catch (e) {
      print('[BgService] Heartbeat Error: $e');
    }
  });
  // ------------------------------------------

  service.on('stop_service').listen((event) {
    heartbeatTimer?.cancel(); // Matikan heartbeat
    positionStream?.cancel();
    service.stopSelf();
    print('[BgService] Service Killed.');
  });

  service.on('stop_alarm').listen((event) {
    print('[BgService] Stopping feedback...');
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
  });

  service.on('start_tracking').listen((event) async {
    // Listener ini tetap ada untuk menerima trigger dari Main Isolate / Geofence Trigger
    startPrecisionTracking();
  });
}

void _triggerBackgroundAlarm(Alarm alarm) {
    try {
      FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true);
      Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 1);
    } catch (_) {}

    final FlutterLocalNotificationsPlugin notifs = FlutterLocalNotificationsPlugin();
    
    // ... setup channel (sama seperti sebelumnya) ...
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'geoalarm_alert', 'GeoAlarm Alert', 
      importance: Importance.max, 
      playSound: true,
    );
    notifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(alarmChannel);

    notifs.show(
      alarm.id.hashCode, // ID Notifikasi (Integer)
      '🚨 SAMPAI TUJUAN: ${alarm.label}',
      'Jarak < ${alarm.radius} meter. Ketuk untuk mematikan!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'geoalarm_alert', 'GeoAlarm Alert',
          importance: Importance.max, 
          priority: Priority.max,
          fullScreenIntent: true, // Muncul di lockscreen
          category: AndroidNotificationCategory.alarm,
          icon: '@mipmap/launcher_icon',
          ongoing: true, // Biar gak bisa di-swipe close sembarangan
          autoCancel: false, // Biar gak ilang pas diklik (kita handle manual)
        )
      ),
      // [PENTING] Payload ini yang dibaca main.dart
      payload: alarm.id, 
    );
}

@pragma('vm:entry-point')
void geofenceCallbackDispatcher() {
  DartPluginRegistrant.ensureInitialized();
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneId, triggerType) async {
      print('[GeofenceService] Geofence Triggered: $triggerType');

      if (triggerType == GeofenceEventType.enter) {
        final service = FlutterBackgroundService();
        await service.startService(); 
        await Future.delayed(const Duration(seconds: 1));
        service.invoke("start_tracking"); 
      } 
      return true;
    },
  );
}

// ==============================================================================
// 3. MAIN CLASS 
// ==============================================================================
class GeofenceService {
  GeofenceService._private();
  static final GeofenceService _instance = GeofenceService._private();
  factory GeofenceService() => _instance;

  final AlarmRepository _repo = AlarmRepository();
  final LocationService _locationService = LocationService();
  bool _initialized = false;
  
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  bool get isRunning => isRunningNotifier.value;

  Future<void> init() async {
    if (_initialized) return;

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
        
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      kBgChannelId,
      kBgChannelName,
      description: 'Background Location Service',
      importance: Importance.low, 
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // CONFIG SERVICE
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: false, 
        isForegroundMode: true,
        notificationChannelId: kBgChannelId, 
        initialNotificationTitle: 'GeoAlarm Service',
        initialNotificationContent: 'Menyiapkan...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(),
    );
    
    _initialized = true;
  }

  Future<void> restoreStatusFromSystem() async {
    final service = FlutterBackgroundService();
    bool isBgRunning = await service.isRunning();
    isRunningNotifier.value = isBgRunning;
  }

  Future<bool> _checkPermissions() async {
    // 1. Cek permission dasar (While in Use) via Geolocator
    LocationPermission permission = await Geolocator.checkPermission();
    
    // JANGAN REQUEST DISINI, KARENA AKAN MEMBUKA SETTINGS TIBA-TIBA
    // Service hanya boleh cek status. Request harus dilakukan di UI (HomeScreen).
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('[GeofenceService] Foreground permission missing.');
      return false;
    }

    // 2. Cek Background Location (Always Allow) via Permission Handler
    var status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      print('[GeofenceService] Background permission missing.');
      return false;
    }
    
    // 3. Notification Permission (Android 13+)
    if (await Permission.notification.isDenied) {
       // Notifikasi mungkin masih oke diminta disini karena popup sistem biasa
       // Tapi lebih aman kalau di UI juga. Kita biarkan dulu untuk notif.
       await Permission.notification.request();
    }

    return true;
  }

  Future<void> startMonitoring() async {
    // 0. Cek apakah ada alarm aktif?
    final alarms = await _repo.fetchAlarms();
    final activeAlarms = alarms.where((a) => a.isActive).toList();
    if (activeAlarms.isEmpty) {
      print('No active alarms. Service will not start.');
      await stopMonitoring();
      return;
    }

    if (!await _checkPermissions()) return;
    await init();
    
    try {
      // 1. START BACKGROUND SERVICE (Mode Standby)
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
         await service.startService();
      }
      
      // 2. START GEOFENCE (Ring 1)
      await GeofenceForegroundService().startGeofencingService(
        contentTitle: 'Siaga Turun - Geofence',
        contentText: 'Memantau zona...',
        notificationChannelId: 'geoalarm_fence_channel',
        serviceId: 525600,
        callbackDispatcher: geofenceCallbackDispatcher,
        notificationIconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic, 
          // Ganti nama icon disini juga
          name: 'launcher_icon', 
        ),
      );
      
      isRunningNotifier.value = true;
      await _setupActiveGeofences();
      
    } catch (e) {
      print('Error starting service: $e');
      isRunningNotifier.value = false;
    }

    // 3. Smart Check Awal
    try {
       Position currentPos = await Geolocator.getCurrentPosition();
       _checkImmediateLogic(currentPos);
    } catch (_) {}
  }

  /// Cek status alarm:
  /// - Jika tidak ada alarm aktif -> Matikan service
  /// - Jika ada alarm aktif -> Pastikan service nyala & update geofence
  Future<void> evaluateServiceState() async {
    final alarms = await _repo.fetchAlarms();
    final activeAlarms = alarms.where((a) => a.isActive).toList();

    if (activeAlarms.isEmpty) {
      // Hapus pengecekan isRunning agar force stop jika memang harus mati
      print('[GeofenceService] No active alarms left. Stopping service.');
      await stopMonitoring();
    } else {
      if (!isRunning) {
        print('[GeofenceService] Found active alarms. Starting service.');
        await startMonitoring();
      } else {
        print('[GeofenceService] Refreshing active geofences.');
        await _setupActiveGeofences();
      }
    }
  }

  Future<void> _setupActiveGeofences() async {
      await GeofenceForegroundService().removeAllGeoFences();
      final alarms = await _repo.fetchAlarms();
      final activeAlarms = alarms.where((a) => a.isActive).toList();

      for (final alarm in activeAlarms) {
        final hybridRadius = alarm.radius + kHybridBufferRadius;
        final zone = Zone(
          id: alarm.id, 
          radius: hybridRadius.toDouble(), 
          coordinates: [LatLng.degree(alarm.lat, alarm.lon)],
          triggers: [GeofenceEventType.enter, GeofenceEventType.exit],
          notificationResponsivenessMs: 10000, 
        );
        await GeofenceForegroundService().addGeofenceZone(zone: zone);
      }
  }
  
  Future<void> _checkImmediateLogic(Position pos) async {
    final alarms = await _repo.fetchAlarms();
    final activeAlarms = alarms.where((a) => a.isActive).toList();
    bool isClose = false;
    for (var alarm in activeAlarms) {
      double dist = _locationService.getDistance(pos.latitude, pos.longitude, alarm.lat, alarm.lon);
      if (dist < (alarm.radius + kHybridBufferRadius)) isClose = true;
    }
    
    if (isClose) {
      final service = FlutterBackgroundService();
      service.invoke("start_tracking");
    }
  }

  Future<void> refreshGeofences() async {
    if (isRunningNotifier.value) await _setupActiveGeofences();
  }

  void stopAlarmFeedback() {
     FlutterRingtonePlayer().stop();
     Vibration.cancel();
     FlutterLocalNotificationsPlugin().cancelAll();
     
     final service = FlutterBackgroundService();
     service.invoke("stop_alarm");
  }

  Future<void> stopMonitoring() async {
     try { await GeofenceForegroundService().stopGeofencingService(); } catch (_) {}
     
     stopAlarmFeedback(); // Stop feedback dulu
     
     final service = FlutterBackgroundService();
     service.invoke("stop_service"); 
     
     isRunningNotifier.value = false;
  }
  
   Future<void> checkImmediateTrigger(Alarm alarm) async {
      try {
      Position currentPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distance = _locationService.getDistance(currentPos.latitude, currentPos.longitude, alarm.lat, alarm.lon);
      if (distance <= alarm.radius) {
          _triggerBackgroundAlarm(alarm);
      } else if (distance <= (alarm.radius + kHybridBufferRadius)) {
          final service = FlutterBackgroundService();
          service.invoke("start_tracking");
      }
    } catch (_) { }
  }
}