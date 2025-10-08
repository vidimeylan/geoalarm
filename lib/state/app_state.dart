import 'package:flutter/material.dart';

// Kelas ini akan menjadi pusat data aplikasi kita
class AppState extends ChangeNotifier {
  Map<String, dynamic>? _selectedStation;
  bool _isTracking = false;

  Map<String, dynamic>? get selectedStation => _selectedStation;
  bool get isTracking => _isTracking;

  // Method untuk mengubah data dan memberitahu UI untuk update
  void selectStation(Map<String, dynamic> station) {
    _selectedStation = station;
    _isTracking = true;
    notifyListeners(); // Beri tahu widget yang mendengarkan bahwa ada perubahan
  }

  void stopTracking() {
    _selectedStation = null;
    _isTracking = false;
    notifyListeners();
  }
}