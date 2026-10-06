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
  // Key Server dari file Signing.txt
  static const String serverKey =
      '4bea70d369fd368d3e3bf6d8da57742ed5e6e470d667ff3171c67e22aaf23ec2';

  // ==========================================
  // DATA IDENTITAS PERANGKAT (BOLEH HARDCODE)
  // ==========================================
  static const String authorizedDeviceId =
      '7913b82ba0bccc52aab63640905016cdb0b42f81b2b8d0a8327be5e3ab622079';
  static const String authorizedAppVersion = '1.0.9700.19381';
  static const String authorizedWebVersion = '153.0.4234.48';
  static const String authorizedPublicIp = '202.46.68.255';
  static const String authorizedCid = 'BVZQHAECHA5dSgBQUA==';
  static const String authorizedPcSpec =
      'ew0KICAiZ2VuZXJhdGVkIjogIjIwMjYtMDktMjggMjA6MzA6MDQiLA0KICAic3lzdGVtIjogew0K%0D%0AICAgICJjb21wdXRlcl9uYW1lIjogIkFaVEVDSE1BSU4iLA0KICAgICJ1c2VyX25hbWUiOiAibXVo%0D%0AYW0iLA0KICAgICJ3aW5kb3dzX3ZlcnNpb24iOiAiV2luZG93cyAxMSBQcm8gMjVIMiIsDQogICAg%0D%0AIndpbmRvd3NfYnVpbGQiOiAiMjYyMDAgKDI1SDIpLjg4OTQiLA0KICAgICJhcmNoaXRlY3R1cmUi%0D%0AOiAieDY0ICg2NC1iaXQgT1MpIC0gUnVubmluZyAzMi1iaXQgcHJvY2VzcyAoV29XNjQpIiwNCiAg%0D%0AICAidXB0aW1lIjogIjEgZGF5cywgMTAgaG91cnMsIDU1IG1pbnV0ZXMsIDQxIHNlY29uZHMiLA0K%0D%0AICAgICJpbnN0YWxsX2RhdGUiOiAiMjAyNS0xMi0yNyAxODo1NTo0MSIsDQogICAgImRldmljZV9p%0D%0AZCI6ICJCNzYwNDFCOS04NjkzLTRBNjItODA1Mi1DNkEwQjVBRTkzOTUiLA0KICAgICJwcm9kdWN0%0D%0AX2lkIjogIjAwMzMxLTEwMDAwLTAwMDAxLUFBNzQyIiwNCiAgICAicmVnaXN0ZXJlZF9vd25lciI6%0D%0AICJtdWhhbW1hZGZhZGlsbGFoMjAxNUBnbWFpbC5jb20iLA0KICAgICJyZWdpc3RlcmVkX29yZ2Fu%0D%0AaXphdGlvbiI6ICIiLA0KICAgICJvc19mdWxsX3ZlcnNpb24iOiAiMTAuMC4yNjIwMC44ODk0IiwN%0D%0ACiAgICAib3NfYnVpbGRfbnVtYmVyIjogMjYyMDAsDQogICAgIm9zX3ViciI6IDg4OTQsDQogICAg%0D%0AIm9zX2NvZGVuYW1lIjogIkdlcm1hbml1bSIsDQogICAgIm9zX3JlbGVhc2UiOiAiMjVIMiIsDQog%0D%0AICAgIm9zX2xhbmd1YWdlIjogIkVuZ2xpc2ggKFVuaXRlZCBTdGF0ZXMpIiwNCiAgICAib3NfaW5z%0D%0AdGFsbGVyX2xhbmd1YWdlIjogIkVuZ2xpc2ggKFVuaXRlZCBTdGF0ZXMpIiwNCiAgICAib3Nfc2Vy%0D%0AdmljZV9wYWNrIjogIi0iLA0KICAgICJvc19yb290IjogIkM6XFxXSU5ET1dTIg0KICB9LA0KICAi%0D%0AaGFyZHdhcmUiOiB7DQogICAgImNwdSI6IHsNCiAgICAgICJuYW1lIjogIkludGVsKFIpIENvcmUo%0D%0AVE0pIGk3LTQ3OTAgQ1BVIEAgMy42MEdIeiIsDQogICAgICAic2VyaWFsIjogIkJGRUJGQkZGMDAw%0D%0AMzA2QzMiDQogICAgfSwNCiAgICAibWVtb3J5Ijogew0KICAgICAgInRvdGFsX2diIjogMTUuOTEs%0D%0ADQogICAgICAiYXZhaWxhYmxlX2diIjogNS40MSwNCiAgICAgICJtb2R1bGVzIjogWw0KICAgICAg%0D%0AICB7DQogICAgICAgICAgIm5hbWUiOiAiRElNTTM6IEtpbmdzdG9uICg0IEdCIEREUjMtMTMzMyBE%0D%0ARFIzIFNEUkFNKSIsDQogICAgICAgICAgInNlcmlhbF9udW1iZXIiOiAiMDJDMDAwMDAwMDAwIg0K%0D%0AICAgICAgICB9LA0KICAgICAgICB7DQogICAgICAgICAgIm5hbWUiOiAiRElNTTE6IEtpbmdzdG9u%0D%0AICg0IEdCIEREUjMtMTMzMyBERFIzIFNEUkFNKSIsDQogICAgICAgICAgInNlcmlhbF9udW1iZXIi%0D%0AOiAiMDEzMDZDMDIwMDY1Ig0KICAgICAgICB9LA0KICAgICAgICB7DQogICAgICAgICAgIm5hbWUi%0D%0AOiAiRElNTTQ6IEtpbmdzdG9uICg0IEdCIEREUjMtMTMzMyBERFIzIFNEUkFNKSIsDQogICAgICAg%0D%0AICAgInNlcmlhbF9udW1iZXIiOiAiMDI5MDAwMDAwMDAwIg0KICAgICAgICB9LA0KICAgICAgICB7%0D%0ADQogICAgICAgICAgIm5hbWUiOiAiRElNTTI6IEh5bml4L0h5dW5kYWkgKDQgR0IgRERSMy0xMzMz%0D%0AIEREUjMgU0RSQU0pIiwNCiAgICAgICAgICAic2VyaWFsX251bWJlciI6ICIwMDAwMDAwMDAwMDAi%0D%0ADQogICAgICAgIH0NCiAgICAgIF0NCiAgICB9LA0KICAgICJncHVzIjogWw0KICAgICAgew0KICAg%0D%0AICAgICAibmFtZSI6ICJJbnRlbChSKSBIRCBHcmFwaGljcyA0NjAwIiwNCiAgICAgICAgInBucF9k%0D%0AZXZpY2VfaWQiOiAiUENJXFxWRU5fODA4NiZERVZfMDQxMiZTVUJTWVNfMDVBNDEwMjgmUkVWXzA2%0D%0AXFwzJjExNTgzNjU5JjAmMTAiDQogICAgICB9DQogICAgXSwNCiAgICAiZHJpdmVzIjogWw0KICAg%0D%0AICAgIkM6fE1pZGFzRm9yY2UgU1NEIDI1NkdCfFNOOiAyMDIyMTIyNDAwMDM4fFNZU1RFTSINCiAg%0D%0AICBdLA0KICAgICJtb3RoZXJib2FyZCI6IHsNCiAgICAgICJtYW51ZmFjdHVyZXIiOiAiRGVsbCBJ%0D%0AbmMuIiwNCiAgICAgICJwcm9kdWN0IjogIjAwVjYySCIsDQogICAgICAic2VyaWFsIjogIi9HWFo1%0D%0ASDgyL0NONzIyMDA1QjkwMFM4LyINCiAgICB9LA0KICAgICJjaGFzc2lzIjogew0KICAgICAgInN5%0D%0Ac3RlbV9tYW51ZmFjdHVyZXIiOiAiRGVsbCBJbmMuIiwNCiAgICAgICJzeXN0ZW1fbW9kZWwiOiAi%0D%0AT3B0aVBsZXggOTAyMCIsDQogICAgICAic3lzdGVtX2ZhbWlseSI6ICIiLA0KICAgICAgInN5c3Rl%0D%0AbV9za3UiOiAiMDVBNCINCiAgICB9LA0KICAgICJiaW9zIjogew0KICAgICAgInNlcmlhbCI6ICJH%0D%0AWFo1SDgyIg0KICAgIH0NCiAgfSwNCiAgIm5ldHdvcmsiOiB7DQogICAgImlwX2FkZHJlc3NlcyI6%0D%0AIFsNCiAgICAgICIxNzIuMzAuMjQwLjEiLA0KICAgICAgIjE5Mi4xNjguMTguNzQiDQogICAgXSwN%0D%0ACiAgICAibWFjX2FkZHJlc3NlcyI6IFsNCiAgICAgICJCbHVldG9vdGggRGV2aWNlIChQZXJzb25h%0D%0AbCBBcmVhIE5ldHdvcmspfDAwOjFBOjdEOkRBOjcxOjE1IiwNCiAgICAgICJJbnRlbChSKSBFdGhl%0D%0Acm5ldCBDb25uZWN0aW9uIEkyMTctTE18NjQ6MDA6NkE6ODA6MDk6RTgiLA0KICAgICAgIkh5cGVy%0D%0ALVYgVmlydHVhbCBFdGhlcm5ldCBBZGFwdGVyfDAwOjE1OjVEOkE5OkYzOkE0Ig0KICAgIF0NCiAg%0D%0AfSwNCiAgInNvZnR3YXJlIjogew0KICAgICJsYW5ndWFnZSI6ICJFbmdsaXNoIChVbml0ZWQgU3Rh%0D%0AdGVzKSIsDQogICAgInRpbWVfem9uZSI6ICJVVEMrMDc6MDAgKFNFIEFzaWEgU3RhbmRhcmQgVGlt%0D%0AZSkiLA0KICAgICJwcm9jZXNzX2NvdW50IjogMjk5LA0KICAgICJzZXJ2aWNlX2NvdW50IjogMzQw%0D%0ADQogIH0sDQogICJkaXNwbGF5Ijogew0KICAgICJyZXNvbHV0aW9uIjogIjE5MjB4MTA4MCIsDQog%0D%0AICAgImRwaSI6IDk2LA0KICAgICJhY3RpdmVfd2luZG93IjogIltBZG1pbmlzdHJhdG9yXSBQcm9q%0D%0AZWN0MSAtIERlbHBoaSAxMSAtIEZybU1haW4iDQogIH0sDQogICJkaXJlY3RvcmllcyI6IHsNCiAg%0D%0AICAiY3VycmVudCI6ICJDOlxcVXNlcnNcXG11aGFtXFxPbmVEcml2ZVxcRG9jdW1lbnRzXFxFbWJh%0D%0AcmNhZGVyb1xcU3R1ZGlvXFxQcm9qZWN0c1xcYnIgbmV3IHBjIGFyaVxcYnJcXFdpbjMyXFxSZWxl%0D%0AYXNlIiwNCiAgICAic3lzdGVtIjogIkM6XFxXSU5ET1dTXFxzeXN0ZW0zMiIsDQogICAgInRlbXAi%0D%0AOiAiQzpcXFVzZXJzXFxtdWhhbVxcQXBwRGF0YVxcTG9jYWxcXFRlbXBcXCINCiAgfQ0KfQ0K';

  /// Menghitung HMAC-SHA256 sesuai rumus:
  /// AppTimeStamp + '|' + Deviceidhwid + '|' + AppVersion
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

  /// Membuat header lengkap
  static Future<Map<String, String>> buildHeaders() async {
    // 1. Timestamp detik dibuat dinamis
    final currentTs = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();

    // 2. Hitung sign dinamis mengikuti timestamp baru
    final dynamicSign = computeSign(
      timestamp: currentTs,
      deviceId: authorizedDeviceId,
      appVersion: authorizedAppVersion,
    );

    // 3. Susun header
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
      'x-ts': currentTs,
      'x-ts2': currentTs,
      'x-sign': dynamicSign,
      'x-device-id': authorizedDeviceId,
      'x-app-version': authorizedAppVersion,
      'x-pcspec': authorizedPcSpec,
      'x-webversion': authorizedWebVersion,
      'x-publicip': authorizedPublicIp,
      'x-cid': authorizedCid,
      'x-platform': 'windows',
    };
  }
}
