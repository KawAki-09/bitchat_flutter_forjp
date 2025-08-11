import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BluetoothConstants {
  static final Guid serviceUuid = Guid("F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C");
  static final Guid characteristicUuid = Guid("A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D");
}

final meshServiceProvider = Provider((ref) => MeshService(ref));

class MeshService {
  final Ref _ref;
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isInitialized = false;
  StreamSubscription? _scanSubscription;

  MeshService(this._ref) {
    _initialize();
  }

  void _initialize() async {
    if (_isInitialized) return;
    await _peripheral.isSupported; // 初期化
    _isInitialized = true;
    print("MeshService initialized.");
  }

  Future<void> start() async {
    print("MeshService starting...");
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;
    await _startAdvertising();
    await _startScan();
    print("MeshService started.");
  }

  Future<void> stop() async {
    print("MeshService stopping...");
    await FlutterBluePlus.stopScan();
    if (await _peripheral.isAdvertising) {
      await _peripheral.stop();
    }
    _scanSubscription?.cancel();
    print("MeshService stopped.");
  }

  Future<void> _startAdvertising() async {
    if (await _peripheral.isAdvertising) {
      await _peripheral.stop();
    }

    final advertiseData = AdvertiseData(
      serviceUuid: BluetoothConstants.serviceUuid.toString(),
      localName: "BitChat User",
    );

    try {
      await _peripheral.start(advertiseData: advertiseData);
      print("Advertising started successfully.");
    } catch (e) {
      print("Error starting advertising: $e");
    }
  }

  Future<void> _startScan() async {
    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          print('${r.device.remoteId}: "${r.advertisementData.localName}" found!');
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [BluetoothConstants.serviceUuid],
        timeout: null,
      );
      print("Scan started successfully.");
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  void sendMessage(String message) {
    print("Sending message: $message");
  }
}