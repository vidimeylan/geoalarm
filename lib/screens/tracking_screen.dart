import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart'; // Import service kita

class TrackingScreen extends StatefulWidget {
  // Terima data destinasi dari layar sebelumnya
  final Map<String, dynamic> destination;
  const TrackingScreen({super.key, required this.destination});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _positionStreamSubscription;
  double _distanceInMeters = 0;
  bool _isAlarmTriggered = false;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    _positionStreamSubscription = _locationService.getPositionStream().listen((Position position) {
      setState(() {
        _distanceInMeters = _locationService.getDistance(
          position.latitude,
          position.longitude,
          widget.destination['lat'],
          widget.destination['lon'],
        );

        // Logika untuk trigger alarm
        if (_distanceInMeters <= 500 && !_isAlarmTriggered) {
          setState(() {
            _isAlarmTriggered = true;
          });
          // TODO: Panggil fungsi untuk menampilkan notifikasi alarm!
          print('ALARM! Jarak sudah dekat!');
          _stopTracking(); // Hentikan tracking setelah alarm berbunyi
        }
      });
    });
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
  }

  @override
  void dispose() {
    _stopTracking(); // Pastikan stream berhenti saat layar ditutup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAlarmTriggered) {
      return _buildAlarmScreen(); // Tampilkan layar alarm
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Perjalanan'),
        backgroundColor: Colors.blue[800],
      ),
      body: Stack(
        children: [
          // TODO: Tampilkan GoogleMap di sini sebagai latar belakang
          // GoogleMap(initialCameraPosition: ...),
          Align(
            alignment: Alignment.bottomCenter,
            child: Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Menuju ${widget.destination['name']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jarak tersisa: ${_distanceInMeters.toStringAsFixed(0)} meter',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alarm akan aktif saat 500m lagi',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk layar alarm
  Widget _buildAlarmScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm'),
        backgroundColor: Colors.blue[800],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_active, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            Text('Anda hampir sampai di\n${widget.destination['name']}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // TODO: Logika untuk kembali ke halaman utama
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Stop Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}