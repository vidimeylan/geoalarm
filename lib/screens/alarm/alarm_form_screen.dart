import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/alarm.dart';
import '../../services/alarm_api_service.dart';
import 'map_picker_screen.dart';

class AlarmFormScreen extends StatefulWidget {
  final Alarm? alarm; // null untuk create

  const AlarmFormScreen({super.key, this.alarm});

  @override
  State<AlarmFormScreen> createState() => _AlarmFormScreenState();
}

class _AlarmFormScreenState extends State<AlarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lonCtrl = TextEditingController();
  final TextEditingController _radiusCtrl = TextEditingController(text: '500');
  bool _isActive = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.alarm != null) {
      final a = widget.alarm!;
      _labelCtrl.text = a.label;
      _latCtrl.text = a.lat.toString();
      _lonCtrl.text = a.lon.toString();
      _radiusCtrl.text = a.radius.toString();
      _isActive = a.isActive;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode() async {
    final lat = double.tryParse(_latCtrl.text);
    final lon = double.tryParse(_lonCtrl.text);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan lat/lon yang valid')));
      return;
    }
    setState(() => _loading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
      final resp = await http.get(url, headers: {'User-Agent': 'geoalarm/1.0'});
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final display = body['display_name'] ?? body['name'] ?? '';
        if (display != null && display.toString().isNotEmpty) {
          _labelCtrl.text = display.toString();
        }
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Strict validation: ensure all required fields are valid
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama/Label tidak boleh kosong')));
      return;
    }
    
    final lat = double.tryParse(_latCtrl.text);
    final lon = double.tryParse(_lonCtrl.text);
    if (lat == null || lat == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Latitude harus berupa angka valid dan tidak nol')));
      return;
    }
    if (lon == null || lon == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Longitude harus berupa angka valid dan tidak nol')));
      return;
    }
    
    final radius = int.tryParse(_radiusCtrl.text) ?? 500;

    final payload = {
      'name': label,
      'latitude': lat,
      'longitude': lon,
      'radius': radius < 10 ? 10 : radius,
      'isActive': _isActive,
    };
    print('[AlarmFormScreen] Final payload to send: $payload');

    setState(() => _loading = true);
    try {
      final service = AlarmApiService();
      if (widget.alarm == null) {
        await service.createAlarm(payload);
      } else {
        await service.updateAlarm(widget.alarm!.id, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'Tambah Alarm' : 'Edit Alarm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: 'Nama / Label'),
                validator: (v) => (v == null || v.isEmpty) ? 'Label wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Lat wajib' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lonCtrl,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Lon wajib' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _reverseGeocode,
                      icon: const Icon(Icons.map),
                      label: const Text('Ambil nama dari OpenStreetMap'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final result = await Navigator.of(context).push<Map<String, dynamic>>(
                              MaterialPageRoute(builder: (_) => MapPickerScreen(initialLat: double.tryParse(_latCtrl.text), initialLon: double.tryParse(_lonCtrl.text), initialRadius: int.tryParse(_radiusCtrl.text))),
                            );
                            if (result != null) {
                              setState(() {
                                _latCtrl.text = result['lat'].toString();
                                _lonCtrl.text = result['lon'].toString();
                                _radiusCtrl.text = result['radius'].toString();
                                if (result['label'] != null && (result['label'] as String).isNotEmpty) {
                                  _labelCtrl.text = result['label'];
                                }
                              });
                            }
                          },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Pilih di peta'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radiusCtrl,
                decoration: const InputDecoration(labelText: 'Radius (meter)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Radius wajib' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Aktifkan alarm'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const CircularProgressIndicator() : Text(widget.alarm == null ? 'Buat' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
