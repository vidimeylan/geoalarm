import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm.dart';
import '../services/auth_service.dart';
import '../services/alarm_api_service.dart';
import '../services/geofence_service.dart';
import 'alarm/alarm_form_screen.dart';
import 'news/news_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siaga Turun', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blueAccent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.home,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Selamat Datang!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pilih menu yang ingin Anda akses',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                _buildMenuButton(
                  icon: Icons.alarm,
                  title: 'Alarm Lokasi',
                  subtitle: 'Kelola alarm berbasis lokasi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlarmSection()),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  icon: Icons.article,
                  title: 'Berita Transportasi',
                  subtitle: 'Baca berita terbaru transportasi',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NewsScreen()),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Siaga Turun - Alarm Lokasi Pintar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlarmSection extends StatefulWidget {
  const AlarmSection({super.key});

  @override
  State<AlarmSection> createState() => _AlarmSectionState();
}

class _AlarmSectionState extends State<AlarmSection> with WidgetsBindingObserver {
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
      // Refresh geofences after adding new alarm
      await GeofenceService().refreshGeofences();
    }
  }

  Future<void> _editAlarm(Alarm alarm) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AlarmFormScreen(alarm: alarm)),
    );
    if (updated == true) {
      await _loadAlarms();
      // Refresh geofences after editing alarm
      await GeofenceService().refreshGeofences();
    }
  }

  Future<void> _toggleAlarm(int index, bool value) async {
    final alarm = _alarms[index];
    try {
      await _api.toggleActive(alarm.id, value);
      setState(() => _alarms[index].isActive = value);
      // Refresh geofences after toggling alarm
      await GeofenceService().refreshGeofences();
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
      // Refresh geofences after deleting alarm
      await GeofenceService().refreshGeofences();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
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
      appBar: AppBar(
        title: const Text('Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      backgroundColor: Colors.black,
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
