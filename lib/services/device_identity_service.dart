import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const String _uuidKey = 'device_uuid';
  final Uuid _uuidGenerator = Uuid();

  Future<String> getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUuid = prefs.getString(_uuidKey);

    if (storedUuid == null) {
      // No UUID found, generate a new one
      storedUuid = _uuidGenerator.v4();
      await prefs.setString(_uuidKey, storedUuid);
      print("Generated and stored new device UUID: $storedUuid");
    } else {
      print("Retrieved existing device UUID: $storedUuid");
    }

    return storedUuid;
  }
}
