import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoHelper {
  DeviceInfoHelper._();

  static Future<String> getDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final raw = info.id;
        if (raw.isNotEmpty) return 'android_$raw';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final vendor = info.identifierForVendor;
        if (vendor != null && vendor.isNotEmpty) return 'ios_$vendor';
      }
    } catch (_) {}
    return 'flutter_${const Uuid().v4()}';
  }
}
