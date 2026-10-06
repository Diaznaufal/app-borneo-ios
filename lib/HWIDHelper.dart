import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class HwidHelper {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ), // Dukung Keychain macOS
  );

  static const _key = 'permanent_device_hwid_key';
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _channel = MethodChannel('com.aplikasi.hwid/android_id');

  static Future<String> _getOrCreateHwid() async {
    // 1. Android: SSAID fisik bawaan sistem (konstan & tahan uninstall)
    if (Platform.isAndroid) {
      try {
        final String? ssaid = await _channel.invokeMethod<String>(
          'getAndroidId',
        );
        if (ssaid != null && ssaid.isNotEmpty) {
          return ssaid;
        }
      } catch (_) {}
    }

    // 2. iOS & macOS: Ambil / Simpan HWID di Apple Keychain (tahan uninstall)
    try {
      final existingId = await _storage.read(key: _key);
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
    } catch (_) {}

    String? rawId;
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      rawId = iosInfo.identifierForVendor;
    } else if (Platform.isMacOS) {
      final macInfo = await _deviceInfo.macOsInfo;
      rawId = macInfo.systemGUID; // GUID unik perangkat macOS
    }

    final finalId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : const Uuid().v4();

    try {
      await _storage.write(key: _key, value: finalId);
    } catch (_) {}

    return finalId;
  }

  static Future<Map<String, dynamic>> getFullDeviceInfo() async {
    final hwid = await _getOrCreateHwid();
    // Membaca otomatis nama platform dari runtime OS ('android', 'ios', 'macos', dll)
    final osName = Platform.operatingSystem;

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      return {
        'hwid': hwid,
        'platform': osName,
        'brand': android.brand,
        'device': android.device,
        'model': android.model,
        'manufacturer': android.manufacturer,
        'os_version': android.version.release,
        'sdk_int': android.version.sdkInt,
        'is_physical': android.isPhysicalDevice,
      };
    } else if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      return {
        'hwid': hwid,
        'platform': osName,
        'brand': 'Apple',
        'device': ios.model,
        'model': ios.utsname.machine,
        'manufacturer': 'Apple',
        'os_version': ios.systemVersion,
        'sdk_int': 0,
        'is_physical': ios.isPhysicalDevice,
      };
    } else if (Platform.isMacOS) {
      final mac = await _deviceInfo.macOsInfo;
      return {
        'hwid': hwid,
        'platform': osName,
        'brand': 'Apple',
        'device': mac.model,
        'model': mac.arch,
        'manufacturer': 'Apple',
        'os_version':
            '${mac.majorVersion}.${mac.minorVersion}.${mac.patchVersion}',
        'kernel_version': mac.kernelVersion,
        'memory_size': mac.memorySize,
      };
    }

    return {'hwid': hwid, 'platform': osName};
  }
}
