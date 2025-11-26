import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final int? initialRadius;

  const MapPickerScreen({super.key, this.initialLat, this.initialLon, this.initialRadius});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _picked;
  int _radius = 500;
  final MapController _mapCtrl = MapController();
  String _label = '';
  
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _searchLoading = false;
  bool _loadingLocation = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLon != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLon!);
      _label = 'Lokasi: ${widget.initialLat!.toStringAsFixed(4)}, ${widget.initialLon!.toStringAsFixed(4)}';
    }
    if (widget.initialRadius != null) _radius = widget.initialRadius!;
    
    _searchCtrl.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _onSearchChanged() async {
    final q = _searchCtrl.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searchLoading = true);
      try {
        final results = await _searchLocationOffline(q);
        if (mounted) {
          setState(() => _suggestions = results);

          // Provide feedback for empty results
          if (results.isEmpty && q.length >= 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak ada hasil. Coba nama yang lebih spesifik'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('[MapPicker] Search error: $e');
        if (mounted) {
          setState(() => _suggestions = []);
          // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pencarian gagal: ${_getErrorMessage(e)}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('connection reset')) return 'Koneksi terputus';
    if (errorStr.contains('timeout')) return 'Timeout';
    if (errorStr.contains('network')) return 'Tidak ada koneksi';
    if (errorStr.contains('refused')) return 'Server tidak merespons';
    return 'Gagal mencari lokasi';
  }

  // Offline search using local hardcoded locations + Nominatim fallback
  Future<List<Map<String, dynamic>>> _searchLocationOffline(String query) async {
    final q = query.toLowerCase();
    
    // Hardcoded popular locations in Indonesia
    final defaultLocations = [
      {
        'name': 'Stasiun Jakarta Kota',
        'display_name': 'Stasiun Jakarta Kota, Jakarta, Indonesia',
        'lat': '-6.1062',
        'lon': '106.8116',
      },
      {
        'name': 'Stasiun Pondok Cina',
        'display_name': 'Stasiun Pondok Cina, Depok, Indonesia',
        'lat': '-6.3690',
        'lon': '106.8323',
      },
      {
        'name': 'Bandara Soekarno-Hatta',
        'display_name': 'Bandara Internasional Soekarno-Hatta, Jakarta, Indonesia',
        'lat': '-6.1256',
        'lon': '106.6594',
      },
      {
        'name': 'Kota Tua Jakarta',
        'display_name': 'Kota Tua, Jakarta, Indonesia',
        'lat': '-6.1347',
        'lon': '106.8110',
      },
      {
        'name': 'Monumen Nasional',
        'display_name': 'Monas, Jakarta, Indonesia',
        'lat': '-6.1753',
        'lon': '106.8249',
      },
      {
        'name': 'Bundaran HI',
        'display_name': 'Bundaran Hotel Indonesia, Jakarta, Indonesia',
        'lat': '-6.1952',
        'lon': '106.8204',
      },
    ];

    // Filter dari hardcoded locations
    final filtered = defaultLocations
        .where((loc) => loc['name']!.toLowerCase().contains(q) || 
                        loc['display_name']!.toLowerCase().contains(q))
        .map((e) => e as Map<String, dynamic>)
        .toList();

    if (filtered.isNotEmpty) return filtered;

    // Fallback: try Nominatim (gracefully fail if blocked)
    try {
      return await _searchNominatim(query);
    } catch (e) {
      print('[MapPicker] Nominatim fallback failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    if (query.trim().isEmpty) {
      print('[MapPicker] Empty query provided to Nominatim');
      return [];
    }

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query.trim())}'
      '&format=json'
      '&limit=8'
      '&countrycodes=id'
      '&addressdetails=1'
      '&bounded=1'
      '&viewbox=-11.0,6.0,141.0,-11.0' // Indonesia bounds
    );

    print('[MapPicker] Nominatim search: $url');

    try {
      final client = http.Client();
      final request = client.get(url, headers: {
        'User-Agent': 'GeoAlarm/1.0',
        'Accept': 'application/json',
      });

      final response = await request.timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          print('[MapPicker] Nominatim returned empty response');
          return [];
        }

        final List<dynamic> decoded = jsonDecode(body);
        final results = decoded.cast<Map<String, dynamic>>();

        print('[MapPicker] Got ${results.length} results from Nominatim for "${query}"');

        // Log first result for debugging
        if (results.isNotEmpty) {
          print('[MapPicker] First result: ${results.first['display_name']}');
        }

        return results;
      } else if (response.statusCode == 429) {
        print('[MapPicker] Nominatim rate limit exceeded');
        throw Exception('Terlalu banyak permintaan ke server pencarian. Tunggu beberapa saat.');
      } else if (response.statusCode == 403) {
        print('[MapPicker] Nominatim access blocked');
        throw Exception('Akses ke server pencarian diblokir. Coba lagi nanti.');
      } else {
        print('[MapPicker] Nominatim error status ${response.statusCode}');
        throw Exception('Server pencarian error (status: ${response.statusCode})');
      }
    } on TimeoutException {
      print('[MapPicker] Nominatim timeout');
      throw Exception('Server pencarian lambat merespons (timeout)');
    } on http.ClientException catch (e) {
      print('[MapPicker] Nominatim network error: ${e.message}');
      throw Exception('Gagal terhubung ke server pencarian: ${e.message}');
    } on FormatException {
      print('[MapPicker] Nominatim response format error');
      throw Exception('Format response server tidak valid');
    } catch (e) {
      print('[MapPicker] Nominatim unexpected error: $e');
      rethrow;
    }
  }
  
  Future<void> _selectSuggestion(Map<String, dynamic> item) async {
    final lat = double.tryParse(item['lat'].toString()) ?? 0;
    final lon = double.tryParse(item['lon'].toString()) ?? 0;
    final displayName = item['display_name'] ?? item['name'] ?? '';
    
    setState(() {
      _picked = LatLng(lat, lon);
      _label = displayName.toString();
      _suggestions = [];
      _searchCtrl.clear();
    });
    
    _mapCtrl.move(_picked!, 15);
  }

  void _confirm() {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih lokasi di peta terlebih dahulu')));
      return;
    }
    Navigator.of(context).pop({'lat': _picked!.latitude, 'lon': _picked!.longitude, 'radius': _radius, 'label': _label});
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _picked = newPos;
        _label = 'Lokasi saat ini: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });

      // Animate map to current location
      _mapCtrl.move(newPos, 15);
    } catch (e) {
      print('[MapPicker] Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapat lokasi: ${e.toString().split('\n').first}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? LatLng(-6.200000, 106.816666);
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Tujuan')),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari lokasi: "Stasiun Gambir", "Monas", "Jakarta Pusat", dll',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchLoading ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        itemCount: _suggestions.length,
                        shrinkWrap: true,
                        itemBuilder: (ctx, i) {
                          final item = _suggestions[i];
                          final displayName = item['display_name'] ?? item['name'] ?? 'Unknown';
                          return ListTile(
                            leading: const Icon(Icons.location_on, size: 18, color: Colors.grey),
                            title: Text(displayName.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            onTap: () => _selectSuggestion(item),
                          );
                        },
                      ),
                    ),
                  )
                else if (!_searchLoading && _searchCtrl.text.trim().isNotEmpty && _searchCtrl.text.trim().length >= 2)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tips pencarian:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Gunakan nama spesifik seperti "Stasiun Gambir"\n'
                          '• Cari landmark seperti "Monas"\n'
                          '• Atau tap langsung di peta',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Map with overlay button
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    center: center,
                    zoom: 13,
                    onTap: (tapPos, point) {
                      setState(() {
                        _picked = point;
                        _label = 'Lokasi dipilih: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.alarm_gps_location',
                    ),
                    if (_picked != null)
                      CircleLayer(circles: [CircleMarker(point: _picked!, color: Colors.blue.withOpacity(0.2), borderStrokeWidth: 2, useRadiusInMeter: true, radius: _radius.toDouble())]),
                    if (_picked != null)
                      MarkerLayer(markers: [
                        Marker(point: _picked!, width: 40, height: 40, builder: (ctx) => Icon(Icons.location_on, color: Colors.red.shade700, size: 40))
                      ]),
                  ],
                ),
                // My Location Button - Overlay on map (bottom-right)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: _loadingLocation ? null : _goToCurrentLocation,
                    backgroundColor: Colors.white,
                    tooltip: 'Lokasi saat ini',
                    child: _loadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                          )
                        : const Icon(Icons.my_location, color: Colors.blue, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Radius (m): '),
                    Expanded(
                      child: Slider(
                        value: _radius.toDouble(),
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        label: '$_radius m',
                        onChanged: (v) => setState(() => _radius = v.toInt()),
                      ),
                    ),
                    Text('$_radius'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirm,
                        child: const Text('Konfirmasi lokasi & radius'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
