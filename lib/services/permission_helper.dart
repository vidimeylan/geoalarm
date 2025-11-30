import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  
  /// Fungsi utama untuk meminta izin lokasi bertahap
  static Future<bool> requestLocationPermission(BuildContext context) async {
    // -----------------------------------------------------------
    // LANGKAH 1: Minta Izin Foreground (Saat Aplikasi Digunakan)
    // -----------------------------------------------------------
    PermissionStatus foregroundStatus = await Permission.locationWhenInUse.status;
    
    if (foregroundStatus.isDenied || foregroundStatus.isProvisional) {
      foregroundStatus = await Permission.locationWhenInUse.request();
    }

    if (!foregroundStatus.isGranted) {
      // Kalau izin dasar aja ditolak, gak bisa lanjut
      _showErrorDialog(context, "Izin lokasi wajib diperlukan agar alarm bisa bekerja.");
      return false;
    }

    // -----------------------------------------------------------
    // LANGKAH 2: Cek & Minta Izin Background (Sepanjang Waktu)
    // -----------------------------------------------------------
    PermissionStatus backgroundStatus = await Permission.locationAlways.status;

    if (backgroundStatus.isGranted) {
      return true; // Sudah aman, izin lengkap
    }

    // Jika belum granted, kita harus kasih edukasi dulu ke user (Syarat Google)
    // Tampilkan Dialog Penjelasan sebelum melempar ke Settings
    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin Lokasi Latar Belakang'),
        content: const Text(
          'Agar alarm bisa berbunyi saat layar mati atau HP dikantongi, '
          'aplikasi membutuhkan izin lokasi "Sepanjang Waktu" (Allow all the time).\n\n'
          'Anda akan diarahkan ke halaman Pengaturan Aplikasi. Mohon ikuti langkah ini:\n'
          '1. Pilih menu **Izin (Permissions)**\n'
          '2. Pilih **Lokasi (Location)**\n'
          '3. Pilih opsi **Sepanjang Waktu (Allow all the time)**',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );

    if (userAgreed == true) {
      // Coba request langsung dulu (siapa tau bisa langsung popup atau redirect ke sub-menu)
      // Jika ini gagal/permanently denied, baru openAppSettings (tapi biasanya ini yang dimau user)
      await Permission.locationAlways.request();
      
      // Kita return false dulu karena kita gak tau user beneran nyalain atau nggak.
      // User harus tekan tombol lagi nanti.
      return false; 
    }

    return false;
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }
}