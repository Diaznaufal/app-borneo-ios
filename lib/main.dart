import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:flutter_application_1/splash_screen.dart';
import 'api_header_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Kunci orientasi landscape absolut untuk iOS dan Android
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // 2. Proteksi Anti-Screenshot hanya aktif di real device release
  if (kReleaseMode && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await ScreenProtector.protectDataLeakageOn();
      dev.log('>>> [SECURITY]: Anti-Screenshot Aktif', name: 'APP_TEST');
    } catch (e) {
      dev.log(
        '>>> [SECURITY ERROR]: Anti-screenshot gagal: $e',
        name: 'APP_TEST',
      );
    }
  }

  // 3. Proteksi Anti-Root / Jailbreak / Emulator (Hanya di mode Release)
  bool isDeviceCompromised = false;
  if (kReleaseMode && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final isJailbroken = await SafeDevice.isJailBroken;
      final isDevMode = await SafeDevice.isDevelopmentModeEnable;
      final isReal = await SafeDevice.isRealDevice;

      if (isJailbroken || isDevMode || !isReal) {
        isDeviceCompromised = true;
        dev.log(
          '>>> [SECURITY WARNING]: Perangkat tidak aman',
          name: 'APP_TEST',
        );
      }
    } catch (e) {
      dev.log('>>> [SECURITY ERROR]: Gagal cek keamanan: $e', name: 'APP_TEST');
    }
  }

  if (isDeviceCompromised) {
    runApp(const SecurityBlockedApp());
    return;
  }

  dev.log('>>> [START]: APLIKASI MULAI BERJALAN', name: 'APP_TEST');

  try {
    final headers = await ApiHeaderProvider.buildHeaders();
    dev.log('>>> [BERHASIL]: Headers API -> $headers', name: 'APP_TEST');
  } catch (e) {
    dev.log('>>> [GAGAL]: Terjadi error headers -> $e', name: 'APP_TEST');
  }

  runApp(const MyApp());
}

class SecurityBlockedApp extends StatelessWidget {
  const SecurityBlockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_bad_rounded, size: 72, color: Colors.redAccent),
                SizedBox(height: 16),
                Text(
                  'Akses Ditolak',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Aplikasi tidak dapat dijalankan pada perangkat yang di-root, emulator, atau developer mode aktif.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xffffffff),
      ),
      home: const SplashScreen(),
    );
  }
}
