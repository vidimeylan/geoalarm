import '../models/alarm.dart';
import 'alarm_api_service.dart';
import 'alarm_local_storage.dart';
import 'auth_service.dart';

class AlarmRepository {
  final AlarmApiService _api = AlarmApiService();
  final AlarmLocalStorage _local = AlarmLocalStorage();
  final AuthService _auth = AuthService();

  // Singleton instance
  static final AlarmRepository _instance = AlarmRepository._internal();
  factory AlarmRepository() => _instance;
  AlarmRepository._internal();

  /// Mengambil alarm.
  /// Prioritas: Local Storage -> API (jika login) -> Update Local
  Future<List<Alarm>> fetchAlarms() async {
    // 1. Ambil dari local dulu (supaya cepat/offline)
    var alarms = await _local.getAlarms();

    // 2. Cek apakah login
    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        // 3. Jika login, lakukan sinkronisasi (Local -> API -> Local)
        // Agar data local yang belum ada di server ter-upload, 
        // dan data server terbaru ter-download.
        await sync();
        
        // 4. Ambil data terbaru dari local setelah sync
        alarms = await _local.getAlarms();
      } catch (e) {
        print('[AlarmRepository] Gagal sync saat fetch, menggunakan data local: $e');
      }
    }
    return alarms;
  }

  Future<Alarm> getAlarm(String id) async {
    // 1. Cek local
    final alarms = await _local.getAlarms();
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (_) {
      // Not found in local
    }

    // 2. Cek API jika login
    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        final alarm = await _api.getAlarm(id);
        // Save to local? Maybe just add it
        await _local.addAlarm(alarm);
        return alarm;
      } catch (e) {
        print('[AlarmRepository] Gagal get alarm detail dari API: $e');
      }
    }
    throw Exception('Alarm not found');
  }

  Future<Alarm> addAlarm(Alarm alarm) async {
    // 1. Simpan ke local
    await _local.addAlarm(alarm);

    // 2. Cek login
    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        // 3. Sync ke API
        final newAlarm = await _api.createAlarm(alarm.toMap());
        // Update local dengan data dari server (misal ID baru)
        await _local.updateAlarm(newAlarm);
        return newAlarm;
      } catch (e) {
        print('[AlarmRepository] Gagal sync add ke API: $e');
        // Tetap return alarm local
      }
    }
    return alarm;
  }

  Future<Alarm> updateAlarm(Alarm alarm) async {
    await _local.updateAlarm(alarm);

    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        final updated = await _api.updateAlarm(alarm.id, alarm.toMap());
        await _local.updateAlarm(updated);
        return updated;
      } catch (e) {
        print('[AlarmRepository] Gagal sync update ke API: $e');
      }
    }
    return alarm;
  }
  
  Future<void> toggleActive(String id, bool active) async {
    // Update local manual karena toggleActive API tidak return object Alarm full biasanya
    // Tapi kita perlu update state local
    final alarms = await _local.getAlarms();
    final index = alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      alarms[index].isActive = active;
      await _local.saveAlarms(alarms);
    }

    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        await _api.toggleActive(id, active);
      } catch (e) {
        print('[AlarmRepository] Gagal sync toggle ke API: $e');
      }
    }
  }

  Future<void> deleteAlarm(String id) async {
    await _local.deleteAlarm(id);

    final token = await _auth.getValidAccessToken();
    if (token != null) {
      try {
        await _api.deleteAlarm(id);
      } catch (e) {
        print('[AlarmRepository] Gagal sync delete ke API: $e');
      }
    }
  }

  /// Sinkronisasi data Local -> API -> Local
  /// Dipanggil saat login berhasil.
  Future<void> sync() async {
    print('[AlarmRepository] Mulai sinkronisasi...');
    final token = await _auth.getValidAccessToken();
    if (token == null) return;

    try {
      // 1. Ambil semua data local
      final localAlarms = await _local.getAlarms();
      
      // 2. Ambil data server saat ini
      final apiAlarms = await _api.fetchAlarms();
      
      // 3. Push data local yang belum ada di server
      final failedUploads = <Alarm>[];
      for (final local in localAlarms) {
        // Cek apakah ID local ini ada di API
        final exists = apiAlarms.any((api) => api.id == local.id);
        
        if (!exists) {
          print('[AlarmRepository] Uploading alarm local ke server: ${local.label}');
          try {
            await _api.createAlarm(local.toMap());
          } catch (e) {
            print('[AlarmRepository] Gagal upload alarm ${local.id}: $e');
            failedUploads.add(local);
          }
        }
      }

      // 4. Ambil data terbaru dari server (setelah upload)
      final finalAlarms = await _api.fetchAlarms();
      
      // 5. Gabungkan dengan yang gagal upload (agar tidak hilang)
      for (final failed in failedUploads) {
        if (!finalAlarms.any((a) => a.id == failed.id)) {
          finalAlarms.add(failed);
        }
      }
      
      // 6. Update local dengan data server + sisa local
      await _local.saveAlarms(finalAlarms);
      print('[AlarmRepository] Sinkronisasi selesai.');
      
    } catch (e) {
      print('[AlarmRepository] Error saat sync: $e');
    }
  }
}
