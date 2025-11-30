import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/alarm.dart';
import '../../services/alarm_repository.dart';
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
    // Hide status bar agar fokus (Immersive Mode)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  @override
  void dispose() {
    // Kembalikan status bar saat keluar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _dismissAlarm() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);

    // [PENTING 1] Matikan Suara & Getar DULUAN (Prioritas Utama)
    GeofenceService().stopAlarmFeedback();

    try {
      // [PENTING 2] Update Status Alarm (Local & Server)
      // Gunakan Repository agar local storage terupdate juga
      try {
        await AlarmRepository().toggleActive(widget.alarm.id, false);
      } catch (e) {
        print("Gagal update status alarm: $e");
      }

      // [PENTING 3] Evaluasi Service Background
      // Cek apakah masih ada alarm lain yang aktif?
      // Jika tidak ada, service akan mati otomatis. Jika ada, refresh geofence.
      await GeofenceService().evaluateServiceState();

      // Kembali ke Home
      if (mounted) {
        // Gunakan navigatorKey global untuk memastikan keluar dari overlay apapun
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // Fallback jika terjadi error sangat fatal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error system: $e')),
        );
        setState(() => _dismissing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope deprecated di Flutter terbaru, tapi masih oke dipakai.
    // Tujuannya agar user GAK BISA tekan tombol back HP, harus tekan tombol di layar.
    return WillPopScope(
      onWillPop: () async => false, 
      child: Scaffold(
        backgroundColor: Colors.red,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasi berdenyut (Opsional, biar keren)
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 1.0, end: 1.2),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                onEnd: () => setState(() {}), // Loop animation (simple hack)
                child: const Icon(
                  Icons.alarm_off,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'SIAP-SIAP TURUN!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.alarm.label,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Radius < ${widget.alarm.radius} meter',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: _dismissing ? null : _dismissAlarm,
                    icon: _dismissing 
                        ? const SizedBox.shrink() 
                        : const Icon(Icons.stop_circle_outlined, size: 32),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    label: _dismissing
                        ? const CircularProgressIndicator(color: Colors.red)
                        : const Text(
                            'MATIKAN ALARM',
                            style: TextStyle(
                              fontSize: 22,
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