import 'package:geolocator/geolocator.dart';

class LocationService {
  // Mendapatkan stream/aliran data posisi secara real-time
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update setiap 10 meter
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  // Menghitung jarak antara dua titik koordinat
  double getDistance(double startLat, double startLon, double endLat, double endLon) {
    return Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
  }
}