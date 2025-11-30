import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';

class AlarmLocalStorage {
  static const String _key = 'local_alarms';

  Future<List<Alarm>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload from disk to handle cross-isolate updates
    final String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Alarm.fromMap(e)).toList();
    } catch (e) {
      print('Error parsing local alarms: $e');
      return [];
    }
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(alarms.map((e) => e.toMap()).toList());
    await prefs.setString(_key, jsonStr);
  }

  Future<void> addAlarm(Alarm alarm) async {
    final alarms = await getAlarms();
    alarms.add(alarm);
    await saveAlarms(alarms);
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      alarms[index] = alarm;
      await saveAlarms(alarms);
    }
  }

  Future<void> deleteAlarm(String id) async {
    final alarms = await getAlarms();
    alarms.removeWhere((a) => a.id == id);
    await saveAlarms(alarms);
  }
  
  Future<void> clearAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
