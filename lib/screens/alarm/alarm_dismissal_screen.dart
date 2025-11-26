import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/alarm.dart';
import '../../services/alarm_api_service.dart';
import '../../services/geofence_service.dart';
import '../../main.dart' show navigatorKey;

class AlarmDismissalScreen extends StatefulWidget {
  final Alarm alarm;

  const AlarmDismissalScreen({
    super.key,
    required this.alarm,
  });

  @override
  State<AlarmDismissalScreen> createState() => _AlarmDismissalScreenState();
}

class _AlarmDismissalScreenState extends State<AlarmDismissalScreen> {
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    // Prevent system back button from working
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);

    try {
      // Stop alarm feedback first
      GeofenceService().stopAlarmFeedback();

      // Toggle alarm to inactive via API
      await AlarmApiService().toggleActive(widget.alarm.id, false);

      // Navigate back to home screen
      if (mounted) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mematikan alarm: $e')),
        );
        setState(() => _dismissing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.alarm,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                'ALARM: ${widget.alarm.label}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Anda memasuki radius ${widget.alarm.radius} meter',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: _dismissing ? null : _dismissAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _dismissing
                        ? const CircularProgressIndicator(color: Colors.red)
                        : const Text(
                            'MATIKAN ALARM',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
