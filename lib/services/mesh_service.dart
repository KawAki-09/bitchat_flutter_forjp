import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_identity_service.dart';
import 'hybrid_connectivity_service.dart';

class BluetoothConstants {
  static final Guid serviceUuid = Guid("F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C");
  static final Guid characteristicUuid = Guid("A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D");
  static const int manufacturerId = 1234;
}

// TODO: Convert this to a StateNotifierProvider to manage state more robustly
final meshServiceProvider = Provider((ref) => MeshService(ref));

// This class now acts as the main coordinator for all connectivity services.
class MeshService {
  final Ref _ref;
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();
  final HybridConnectivityService _hybridService = HybridConnectivityService();

  StreamSubscription? _bleScanSubscription;
  String? _deviceUuid;

  // Expose the device stream from the hybrid service for the UI
  Stream<List<Device>> get nearbyDevicesStream => _hybridService.devicesStream;

  MeshService(this._ref) {
    _initialize();
  }

  void _initialize() async {
    _deviceUuid = await _deviceIdentity.getDeviceUuid();
    print("MeshService initialized with UUID: $_deviceUuid");
    
    // Initialize the hybrid service, passing the BLE connection callback
    await _hybridService.init(
      onBleConnectRequest: initiateBleConnectionByUuid,
    );
  }

  Future<void> start() async {
    print("MeshService starting all services...");
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;
    
    // Advertising and browsing/scanning are now started from within the services' init methods
    // We just need to ensure they are initialized.
    await startBleAdvertising();
  }

  Future<void> stop() async {
    print("MeshService stopping all services...");
    await stopBleAdvertising();
    _hybridService.dispose();
    _bleScanSubscription?.cancel();
  }

  // --- BLE Specific Methods ---

  Future<void> startBleAdvertising() async {
    if (await _blePeripheral.isAdvertising) {
      await _blePeripheral.stop();
    }
    if (_deviceUuid == null) return;

    List<int> uuidBytes = utf8.encode(_deviceUuid!);
    final advertiseData = AdvertiseData(
      serviceUuid: BluetoothConstants.serviceUuid.toString(),
      manufacturerId: BluetoothConstants.manufacturerId,
      manufacturerData: Uint8List.fromList(uuidBytes),
    );

    try {
      await _blePeripheral.start(advertiseData: advertiseData);
      print("BLE Advertising started successfully.");
    } catch (e) {
      print("Error starting BLE advertising: $e");
    }
  }
  
  Future<void> stopBleAdvertising() async {
      if (await _blePeripheral.isAdvertising) {
          await _blePeripheral.stop();
      }
  }

  Future<void> initiateBleConnectionByUuid(String targetUuid) async {
    print("Attempting to connect via BLE to UUID: $targetUuid");
    await _bleScanSubscription?.cancel(); // Cancel any ongoing scan

    // Start a new scan specifically for the target UUID
    _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        var manuData = r.advertisementData.manufacturerData;
        if (manuData.containsKey(BluetoothConstants.manufacturerId)) {
          try {
            String discoveredUuid = utf8.decode(manuData[BluetoothConstants.manufacturerId]!);
            if (discoveredUuid == targetUuid) {
              print('Found target device via BLE: ${r.device.remoteId}');
              FlutterBluePlus.stopScan();
              _bleScanSubscription?.cancel();
              // TODO: Implement actual connection logic to the found device 'r.device'
              print("TODO: Connect to ${r.device.remoteId}");
            }
          } catch (e) { /* Ignore decode errors */ }
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: Duration(seconds: 10)); // Scan for 10 seconds
    print("Started targeted BLE scan for UUID: $targetUuid");
  }


  // --- Hybrid Service Passthrough Methods ---

  void sendMessage(String deviceId, String message) {
    // TODO: Determine if deviceId is for a BLE or Nearby connection
    _hybridService.sendMessage(deviceId, message);
  }
}