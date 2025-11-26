// di main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/alarm/alarm_dismissal_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'services/alarm_api_service.dart';
import 'models/alarm.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (details) async {
      if (details.payload != null) {
        _handleAlarmNotification(details.payload!);
      }
    },
  );

  runApp(const MyApp());
}

Future<void> _handleAlarmNotification(String alarmId) async {
  try {
    final alarm = await AlarmApiService().getAlarm(alarmId);
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmDismissalScreen(alarm: alarm),
        fullscreenDialog: true,
      ),
    );
  } catch (e) {
    print('Error handling alarm notification: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Alarm',
      navigatorKey: navigatorKey,
      home: const AuthGate(),
      routes: {
        '/alarm_dismissal': (context) => const AlarmDismissalScreenPlaceholder(),
      },
    );
  }
}

class AlarmDismissalScreenPlaceholder extends StatelessWidget {
  const AlarmDismissalScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Loading alarm...')),
    );
  }
}
