import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm.dart';
import '../services/auth_service.dart';
import '../services/alarm_api_service.dart';
import 'alarm/alarm_form_screen.dart';
import '../services/geofence_service.dart';

class AlarmHomepageScreen extends StatefulWidget {
  final Future<void> Function()? onLogout;

  const AlarmHomepageScreen({super.key, this.onLogout});

  @override
  State<AlarmHomepageScreen> createState() => _AlarmHomepageScreenState();
}

class _AlarmHomepageScreenState extends State<AlarmHomepageScreen> with WidgetsBindingObserver {
  late Timer _timer;
  late DateTime _currentTime;
  List<Alarm> _alarms = [];
  final AlarmApiService _api = AlarmApiService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTime = DateTime.now();
    _loadAlarms(); // Muat data alarm dari API saat aplikasi dimulai
    // Mulai monitoring geofence saat layar alarm aktif
    GeofenceService().startMonitoring();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh alarms when app resumes (e.g., after dismissing alarm)
      _loadAlarms();
    }
  }

  Future<void> _loadAlarms() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchAlarms();
      if (mounted) setState(() => _alarms = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat alarm: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAlarm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AlarmFormScreen()),
    );
    if (created == true) {
      await _loadAlarms();
    }
  }

  Future<void> _editAlarm(Alarm alarm) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AlarmFormScreen(alarm: alarm)),
    );
    if (updated == true) await _loadAlarms();
  }

  Future<void> _toggleAlarm(int index, bool value) async {
    final alarm = _alarms[index];
    try {
      await _api.toggleActive(alarm.id, value);
      setState(() => _alarms[index].isActive = value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal toggle: $e')));
    }
  }

  Future<void> _deleteAlarm(int index) async {
    final alarm = _alarms[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Hapus alarm ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAlarm(alarm.id);
      if (mounted) setState(() => _alarms.removeAt(index));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    GeofenceService().stopMonitoring();
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
          _loading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : _buildAlarmList(),
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
      child: RefreshIndicator(
        onRefresh: _loadAlarms,
        child: _alarms.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 80),
                  Center(child: Text('Tidak ada alarm', style: TextStyle(color: Colors.grey[400]))),
                ],
              )
            : ListView.separated(
                itemCount: _alarms.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[800], indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
          final alarm = _alarms[index];
          final createdStr = alarm.createdDate != null
              ? DateFormat('d MMM yyyy, HH:mm').format(alarm.createdDate!)
              : 'Tanggal tidak diketahui';
          
          return ListTile(
            onTap: () => _editAlarm(alarm),
            leading: Icon(Icons.location_on, color: alarm.isActive ? Colors.white : Colors.grey, size: 28),
            title: Text(
              alarm.label,
              style: TextStyle(
                color: alarm.isActive ? Colors.white : Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                decoration: alarm.isActive ? TextDecoration.none : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '📅 $createdStr',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 Radius: ${alarm.radius} m',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: alarm.isActive,
                  onChanged: (bool value) => _toggleAlarm(index, value),
                  activeTrackColor: Colors.blueAccent.withOpacity(0.5),
                  activeColor: Colors.blueAccent,
                ),
                IconButton(
                  onPressed: () => _deleteAlarm(index),
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus alarm',
                ),
              ],
            ),
          );
                },
              ),
      ),
    );
  }
}
