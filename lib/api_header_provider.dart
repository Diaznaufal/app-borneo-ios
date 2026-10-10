// import 'dart:convert';
// import 'dart:io';
// import 'package:crypto/crypto.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:http/http.dart' as http;
// import 'package:package_info_plus/package_info_plus.dart';
// import 'HWIDHelper.dart';

// class ApiHeaderProvider {
//   // Key Server dari file Signing.txt
//   static const String serverKey =
//       '4bea70d369fd368d3e3bf6d8da57742ed5e6e470d667ff3171c67e22aaf23ec2';

//   static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

//   /// 1. Mengambil IP Publik Asli Internet Perangkat
//   static Future<String> fetchPublicIp() async {
//     try {
//       final response = await http
//           .get(Uri.parse('https://api.ipify.org'))
//           .timeout(const Duration(seconds: 4));
//       if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
//         return response.body.trim();
//       }
//     } catch (_) {
//       // Fallback default jika offline atau timeout
//     }
//     return '202.46.68.255';
//   }

//   /// 2. Mengambil Versi Engine WebView/Browser Perangkat
//   static Future<String> fetchWebVersion() async {
//     try {
//       if (Platform.isAndroid) {
//         final android = await _deviceInfoPlugin.androidInfo;
//         // Format versi WebView/Browser Android yang konsisten dengan rilis OS
//         return '${android.version.release}.0.${android.version.sdkInt}.0';
//       } else if (Platform.isIOS) {
//         final ios = await _deviceInfoPlugin.iosInfo;
//         return ios.systemVersion;
//       }
//     } catch (_) {}
//     return '153.0.4234.48'; // Fallback template standar
//   }

//   /// 3. Menghasilkan Client ID (x-cid) Berbasis Identitas Perangkat (Base64)
//   static String generateCid(String deviceId) {
//     // Membuat identifier berbasis hash singkat deviceId agar konstan di perangkat yang sama
//     final bytes = utf8.encode(deviceId);
//     final base64String = base64Encode(bytes);
//     if (base64String.length >= 16) {
//       return base64String.substring(0, 16) + '==';
//     }
//     return base64String.padRight(16, 'A') + '==';
//   }

//   /// Menghitung HMAC-SHA256 sesuai rumus Signing.txt:
//   /// AppTimeStamp + '|' + Deviceidhwid + '|' + AppVersion
//   static String computeSign({
//     required String timestamp,
//     required String deviceId,
//     required String appVersion,
//     String key = serverKey,
//   }) {
//     final rawData = '$timestamp|$deviceId|$appVersion';
//     final hmac = Hmac(sha256, utf8.encode(key));
//     final digest = hmac.convert(utf8.encode(rawData));
//     return digest.toString().toLowerCase();
//   }

//   /// Membuat header lengkap secara realtime
//   static Future<Map<String, String>> buildHeaders({
//     String? publicIp,
//     String? webVersion,
//     String? cid,
//     String? platform,
//   }) async {
//     // 1. Ambil info device dari HwidHelper (SSAID di Android / Keychain di iOS)
//     final deviceInfo = await HwidHelper.getFullDeviceInfo();
//     final deviceId = deviceInfo['hwid'] as String;

//     // 2. Ambil versi aplikasi secara dinamis
//     final packageInfo = await PackageInfo.fromPlatform();
//     final appVersion = packageInfo.version;

//     // 3. Waktu realtime saat request dieksekusi (Unix Epoch detik)
//     final currentTs = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
//         .toString();

//     // 4. Hitung signature HMAC-SHA256
//     final sign = computeSign(
//       timestamp: currentTs,
//       deviceId: deviceId,
//       appVersion: appVersion,
//     );

//     // 5. Generate x-pcspec dari spesifikasi perangkat (Base64)
//     final specJson = jsonEncode({
//       'generated': DateTime.now().toUtc().toIso8601String(),
//       'system': deviceInfo,
//     });
//     final pcSpecBase64 = Uri.encodeComponent(
//       base64Encode(utf8.encode(specJson)),
//     );

//     // 6. Tangkap nilai dinamis untuk IP, WebVersion, CID, dan Platform
//     final resolvedPublicIp = publicIp ?? await fetchPublicIp();
//     final resolvedWebVersion = webVersion ?? await fetchWebVersion();
//     final resolvedCid = cid ?? generateCid(deviceId);
//     final resolvedPlatform =
//         platform ??
//         (deviceInfo['platform'] as String? ?? Platform.operatingSystem);

//     // 7. Susun map header lengkap
//     return {
//       'Accept':
//           'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//       'Connection': 'keep-alive',
//       'x-ts': currentTs,
//       'x-ts2': currentTs,
//       'x-sign': sign,
//       'x-device-id': deviceId,
//       'x-app-version': appVersion,
//       'x-pcspec': pcSpecBase64,
//       'x-webversion': resolvedWebVersion,
//       'x-publicip': resolvedPublicIp,
//       'x-cid': resolvedCid,
//       'x-platform': resolvedPlatform,
//     };
//   }
// }

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ApiHeaderProvider {
  // ==========================================
  // KEY SERVER (dari Signing.txt)
  // ==========================================
  static const String serverKey =
      '4bea70d369fd368d3e3bf6d8da57742ed5e6e470d667ff3171c67e22aaf23ec2';

  // ==========================================
  // DATA IDENTITAS PERANGKAT
  // ==========================================
  static const String authorizedDeviceId =
      '7913b82ba0bccc52aab63640905016cdb0b42f81b2b8d0a8327be5e3ab622079';
  static const String authorizedAppVersion = '1.0.9700.19381';
  static const String authorizedWebVersion = '153.0.4234.48';
  static const String authorizedPublicIp = '202.46.68.255';
  static const String authorizedCid = 'BVZQHAECHA5dSgBQUA==';

  // ==========================================
  // STRUKTUR JSON ASLI (Sesuai Arahan Backend)
  // ==========================================
  static final Map<String, dynamic> _pcSpecJson = {
    "generated": "2026-09-28 20:30:04",
    "system": {
      "computer_name": "AZTECHMAIN",
      "user_name": "muham",
      "windows_version": "Windows 11 Pro 25H2",
      "windows_build": "26200 (25H2).8894",
      "architecture": "x64 (64-bit OS) - Running 32-bit process (WoW64)",
      "uptime": "1 days, 10 hours, 55 minutes, 41 seconds",
      "install_date": "2025-12-27 18:55:41",
      "device_id": authorizedDeviceId,
      "product_id": "00331-10000-00001-AA742",
      "registered_owner": "muhammadfadillah2015@gmail.com",
      "registered_organization": "",
      "os_full_version": "10.0.26200.8894",
      "os_build_number": 26200,
      "os_ubr": 8894,
      "os_codename": "Germanium",
      "os_release": "25H2",
      "os_language": "English (United States)",
      "os_installer_language": "English (United States)",
      "os_service_pack": "-",
      "os_root": "C:\\WINDOWS"
    },
    "hardware": {
      "cpu": {
        "name": "Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz",
        "serial": "BFEBFBFF000306C3"
      },
      "memory": {
        "total_gb": 15.91,
        "available_gb": 5.41,
        "modules": [
          {
            "name": "DIMM3: Kingston (4 GB DDR3-1333 DDR3 SDRAM)",
            "serial_number": "02C000000000"
          },
          {
            "name": "DIMM1: Kingston (4 GB DDR3-1333 DDR3 SDRAM)",
            "serial_number": "01306C020065"
          },
          {
            "name": "DIMM4: Kingston (4 GB DDR3-1333 DDR3 SDRAM)",
            "serial_number": "029000000000"
          },
          {
            "name": "DIMM2: Hynix/Hyundai (4 GB DDR3-1333 DDR3 SDRAM)",
            "serial_number": "000000000000"
          }
        ]
      },
      "gpus": [
        {
          "name": "Intel(R) HD Graphics 4600",
          "pnp_device_id":
              "PCI\\VEN_8086&DEV_0412&SUBSYS_05A41028&REV_06\\3&11583659&0&10"
        }
      ],
      "drives": [
        "C:|MidasForce SSD 256GB|SN: 2022122400038|SYSTEM"
      ],
      "motherboard": {
        "manufacturer": "Dell Inc.",
        "product": "00V62H",
        "serial": "/GXZ5H82/CN722005B900S8/"
      },
      "chassis": {
        "system_manufacturer": "Dell Inc.",
        "system_model": "OptiPlex 9020",
        "system_family": "",
        "system_sku": "05A4"
      },
      "bios": {
        "serial": "GXZ5H82"
      }
    },
    "network": {
      "ip_addresses": [
        "172.30.240.1",
        "192.168.18.74"
      ],
      "mac_addresses": [
        "Bluetooth Device (Personal Area Network)|00:1A:7D:DA:71:15",
        "Intel(R) Ethernet Connection I217-LM|64:00:6A:80:09:E8",
        "Hyper-V Virtual Ethernet Adapter|00:15:5D:A9:F3:A4"
      ]
    },
    "software": {
      "language": "English (United States)",
      "time_zone": "UTC+07:00 (SE Asia Standard Time)",
      "process_count": 299,
      "service_count": 340
    },
    "display": {
      "resolution": "1920x1080",
      "dpi": 96,
      "active_window": "[Administrator] Project1 - Delphi 11 - FrmMain"
    },
    "directories": {
      "current":
          "C:\\Users\\muham\\OneDrive\\Documents\\Embarcadero\\Studio\\Projects\\br new pc ari\\br\\Win32\\Release",
      "system": "C:\\WINDOWS\\system32",
      "temp": "C:\\Users\\muham\\AppData\\Local\\Temp\\"
    }
  };

  // Langsung encode objek Map ke Base64 murni tanpa karakter escape
  static final String authorizedPcSpec =
      base64Encode(utf8.encode(jsonEncode(_pcSpecJson)));

  // ==========================================
  // SIGNING
  // ==========================================
  static String computeSign({
    required String timestamp,
    required String deviceId,
    required String appVersion,
    String key = serverKey,
  }) {
    final rawData = '$timestamp|$deviceId|$appVersion';
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(rawData));
    return digest.toString().toLowerCase();
  }

  // ==========================================
  // BUILD HEADERS
  // ==========================================
  static Future<Map<String, String>> buildHeaders({
    String? contentType,
  }) async {
    final now = DateTime.now();

    final ts1 = (now.millisecondsSinceEpoch ~/ 1000).toString();
    final ts2 = now.millisecondsSinceEpoch.toString();

    final dynamicSign = computeSign(
      timestamp: ts1,
      deviceId: authorizedDeviceId,
      appVersion: authorizedAppVersion,
    );

    final headers = <String, String>{
      'x-ts': ts1,
      'x-ts2': ts2,
      'x-sign': dynamicSign,
      'x-device-id': authorizedDeviceId,
      'x-app-version': authorizedAppVersion,
      'x-pcspec': authorizedPcSpec,
      'x-webversion': authorizedWebVersion,
      'x-publicip': authorizedPublicIp,
      'x-cid': authorizedCid,
      'x-platform': 'windows',
    };

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    return headers;
  }

  // ==========================================
  // HELPER DEBUG
  // ==========================================
  static void debugHeaders(Map<String, String> h) {
    // ignore: avoid_print
    print('===== REQUEST HEADERS =====');
    h.forEach((k, v) {
      // ignore: avoid_print
      print('$k: $v');
    });
    // ignore: avoid_print
    print('===========================');
  }
}