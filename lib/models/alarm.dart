// Enum untuk membedakan jenis alarm
enum AlarmType { time, location }

class Alarm {
  String id; // Tambahkan ID unik untuk setiap alarm
  AlarmType type;
  String time;
  double lon;
  double lat;
  String label;
  bool isActive;

  Alarm({
    required this.id,
    required this.type,
    this.time = '',
    this.lon = 0.0,
    this.lat = 0.0,
    required this.label,
    this.isActive = true,
  });

  // Method untuk mengubah objek Alarm menjadi Map (untuk JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(), // Simpan enum sebagai String
      'time': time,
      'lon': lon,
      'lat': lat,
      'label': label,
      'isActive': isActive,
    };
  }

  // Method untuk membuat objek Alarm dari Map (dari JSON)
  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      id: map['id'],
      // Ubah String kembali menjadi enum
      type: AlarmType.values.firstWhere((e) => e.toString() == map['type']),
      time: map['time'],
      lon: map['lon'],
      lat: map['lat'],
      label: map['label'],
      isActive: map['isActive'],
    );
  }
}