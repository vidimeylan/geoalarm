import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Sesuaikan import ini dengan struktur folder kamu
import 'models/alarm.dart';
import 'screens/alarm/alarm_dismissal_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/alarm_repository.dart';
import 'services/geofence_service.dart';

// 1. GLOBAL NAVIGATOR KEY (Wajib Global)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 2. GLOBAL NOTIFICATION PLUGIN
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi Notifikasi
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // Handler saat aplikasi sedang jalan (Background/Foreground)
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null && response.payload!.isNotEmpty) {
        print('🔔 Notifikasi diklik (App Running): ${response.payload}');
        GeofenceService().stopAlarmFeedback();
        _navigateToDismissal(response.payload!);
      }
    },
  );

  // 3. LOGIC COLD START (Saat aplikasi mati total)
  // Cek apakah aplikasi ini dibangunkan oleh notifikasi?
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  String? initialPayload;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    initialPayload = notificationAppLaunchDetails?.notificationResponse?.payload;
    print('🚀 Aplikasi dibuka dari Notifikasi (Cold Start). Payload: $initialPayload');
  }

  runApp(MyApp(initialPayload: initialPayload));
}

// Fungsi Navigasi Terpusat
void _navigateToDismissal(String alarmId) async {
  try {
    print('🔄 Mengambil data alarm ID: $alarmId ...');
    // Ambil detail alarm dari API agar halaman dismiss tidak kosong
    final alarm = await AlarmRepository().getAlarm(alarmId);
    
    // Gunakan navigatorKey global untuk pindah halaman
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmDismissalScreen(alarm: alarm),
        fullscreenDialog: true, // Agar muncul slide dari bawah (opsional)
      ),
    );
  } catch (e) {
    print('❌ Gagal navigasi ke alarm dismissal: $e');
  }
}

class MyApp extends StatefulWidget {
  final String? initialPayload;
  const MyApp({super.key, this.initialPayload});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Jika ada payload dari Cold Start, jalankan navigasi setelah frame pertama
    if (widget.initialPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDismissal(widget.initialPayload!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siaga Turun',
      navigatorKey: navigatorKey, // Pasang Key Disini
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      // Ganti dengan widget auth/home kamu yang benar
      home: const HomeScreen(), 
      routes: {
        '/auth': (context) => AuthScreen(
          onAuthenticated: () {
            // Setelah login berhasil, kembali ke halaman sebelumnya (Home)
            Navigator.of(context).pop();
          },
        ),
      },
    );
  }
}