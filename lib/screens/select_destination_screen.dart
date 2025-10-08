import 'package:flutter/material.dart';

// Dummy data, nantinya bisa dari database atau API
final List<Map<String, dynamic>> stations = [
  {'name': 'Stasiun Tanah Abang', 'lat': -6.1855, 'lon': 106.8093},
  {'name': 'Stasiun Duren Kalibata', 'lat': -6.2435, 'lon': 106.8533},
  {'name': 'Stasiun Cawang', 'lat': -6.2429, 'lon': 106.8680},
];

class SelectDestinationScreen extends StatelessWidget {
  const SelectDestinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Tujuan'),
        backgroundColor: Colors.blue[800],
      ),
      body: ListView.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          return ListTile(
            title: Text(station['name']),
            onTap: () {
              // TODO: Kirim data stasiun terpilih ke halaman tracking
              // dan navigasi ke sana.
              print('Stasiun terpilih: ${station['name']}');
              // Navigator.push(context, MaterialPageRoute(builder: (context) => TrackingScreen(destination: station)));
            },
          );
        },
      ),
    );
  }
}