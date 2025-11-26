// Enum untuk membedakan jenis alarm (sekarang hanya location)
enum AlarmType { location }

class Alarm {
  String id;
  double lon;
  double lat;
  String label;
  bool isActive;
  int radius; // dalam meter
  DateTime? createdDate;

  Alarm({
    required this.id,
    this.lon = 0.0,
    this.lat = 0.0,
    required this.label,
    this.isActive = true,
    this.radius = 500,
    this.createdDate,
  });

  // Method untuk mengubah objek Alarm menjadi Map (untuk JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lat': lat,
      'lon': lon,
      'label': label,
      'isActive': isActive,
      'radius': radius,
      'createdDate': createdDate?.toIso8601String(),
    };
  }

  // Method untuk membuat objek Alarm dari Map (dari JSON)
  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      id: map['id'],
      lon: map['lon'],
      lat: map['lat'],
      label: map['label'],
      isActive: map['isActive'],
      radius: map['radius'] is int ? map['radius'] : (map['radius'] is String ? int.tryParse(map['radius']) ?? 500 : 500),
      createdDate: map['createdDate'] != null ? DateTime.tryParse(map['createdDate'].toString()) : null,
    );
  }
}