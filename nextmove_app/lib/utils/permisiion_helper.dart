// lib/utils/permissions_helper.dart
import 'package:geolocator/geolocator.dart';

class PermissionsHelper {
  static Future<bool> requestLocationPermission() async {
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    return status == LocationPermission.whileInUse ||
           status == LocationPermission.always;
  }
}