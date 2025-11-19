import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Package untuk membuat ID unik
import '../models/alarm.dart';
import '../services/auth_service.dart';

class AlarmHomepageScreen extends StatefulWidget {
  final Future<void> Function()? onLogout;

  const AlarmHomepageScreen({super.key, this.onLogout});

  @override
  State<AlarmHomepageScreen> createState() => _AlarmHomepageScreenState();
}

class _AlarmHomepageScreenState extends State<AlarmHomepageScreen> {
  late Timer _timer;
  late DateTime _currentTime;
  List<Alarm> _alarms = [];
  final Uuid _uuid = Uuid(); // Inisialisasi Uuid

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _loadAlarms(); // Muat data alarm saat aplikasi dimulai

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }
  
  // --- Fungsi untuk Load, Save, dan Update Alarm ---

  Future<void> _loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? alarmsString = prefs.getString('alarms');
    if (alarmsString != null) {
      final List<dynamic> alarmJson = jsonDecode(alarmsString);
      setState(() {
        _alarms = alarmJson.map((json) => Alarm.fromMap(json)).toList();
      });
    }
  }

  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final String alarmsString = jsonEncode(_alarms.map((alarm) => alarm.toMap()).toList());
    await prefs.setString('alarms', alarmsString);
  }

  void _addAlarm() {
    // Contoh menambah alarm baru berdasarkan WAKTU
    final newAlarm = Alarm(
      id: _uuid.v4(), // Buat ID unik
      type: AlarmType.time,
      label: 'Alarm Baru',
      time: '10:00',
      isActive: true,
    );
    setState(() => _alarms.add(newAlarm));
    _saveAlarms(); // Simpan setiap kali ada alarm baru
  }
  
  void _toggleAlarm(int index, bool value) {
    setState(() => _alarms[index].isActive = value);
    _saveAlarms(); // Simpan setiap kali status alarm diubah
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (widget.onLogout != null)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Keluar',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildDigitalClock(),
          _buildAlarmList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAlarm,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDigitalClock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      child: Column(
        children: [
          Text(DateFormat('HH:mm').format(_currentTime),
            style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
          Text(DateFormat('E, d MMM').format(_currentTime),
            style: TextStyle(color: Colors.grey[400], fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    return Expanded(
      child: ListView.separated(
        itemCount: _alarms.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey[800], indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final alarm = _alarms[index];
          // Tentukan ikon dan teks berdasarkan jenis alarm
          final IconData icon = alarm.type == AlarmType.time ? Icons.access_time : Icons.location_on;
          final String title = alarm.type == AlarmType.time ? alarm.time : 'Lokasi';
          
          return ListTile(
            leading: Icon(icon, color: alarm.isActive ? Colors.white : Colors.grey, size: 28),
            title: Text(title,
              style: TextStyle(
                color: alarm.isActive ? Colors.white : Colors.grey,
                fontSize: 32,
                fontWeight: FontWeight.w500,
                decoration: alarm.isActive ? TextDecoration.none : TextDecoration.lineThrough,
              )),
            subtitle: Text(alarm.label,
              style: TextStyle(color: alarm.isActive ? Colors.white70 : Colors.grey)),
            trailing: Switch(
              value: alarm.isActive,
              onChanged: (bool value) => _toggleAlarm(index, value),
              activeTrackColor: Colors.blueAccent.withOpacity(0.5),
              activeColor: Colors.blueAccent,
            ),
          );
        },
      ),
    );
  }
}
