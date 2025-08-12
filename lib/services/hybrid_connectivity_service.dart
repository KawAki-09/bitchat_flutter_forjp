import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'device_identity_service.dart';

class HybridConnectivityService {
  final NearbyService _nearbyService = NearbyService();
  final DeviceIdentityService _deviceIdentityService = DeviceIdentityService();
  final String serviceType = 'mp-connection';
  final String _baseDeviceName = "BitChat User";

  // Callback to request a BLE connection
  late final Function(String uuid) onBleConnectRequest; // ★ ADD

  // State Management
  List<Device> _foundDevices = [];
  final List<Device> _connectedDevices = [];
  final StreamController<List<Device>> _devicesController = StreamController<List<Device>>.broadcast();
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  final StreamController<Map<String, dynamic>> _dataReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataReceivedStream => _dataReceivedController.stream;

  final int multipeerConnectionLimit = 7;

  // ★ CHANGE: Added onBleConnectRequest callback
  Future<void> init({required this.onBleConnectRequest}) async {
    String platformName = Platform.isIOS ? "[iOS]" : "[Android]";
    String deviceUuid = await _deviceIdentityService.getDeviceUuid();

    String advertisingName = '$platformName[$deviceUuid]$_baseDeviceName';

    await _nearbyService.init(
      serviceType: serviceType,
      deviceName: advertisingName,
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) {
        if (isRunning) {
          print("Nearby Service is running. Advertising as $advertisingName");
          startAdvertising();
          startBrowsing();
        }
      },
    );

    _nearbyService.stateChangedSubscription(callback: _handleStateChange);
    _nearbyService.dataReceivedSubscription(callback: (data) {
      print("Data received from ${data['deviceId']}: ${data['message']}");
      _dataReceivedController.add(data);
    });
  }

  String? _getUuidFromDeviceName(String deviceName) {
    final regex = RegExp(r'\[([a-fA-F0-9-]{36})\]');
    final match = regex.firstMatch(deviceName);
    return match?.group(1);
  }

  void _handleStateChange(List<Device> devicesList) {
    _foundDevices = devicesList;
    _connectedDevices.clear();
    int currentIOSPeers = 0;

    for (var device in devicesList) {
      if (device.state == SessionState.connected) {
        _connectedDevices.add(device);
        if (device.deviceName.startsWith("[iOS]")) {
          currentIOSPeers++;
        }
      }
    }

    _devicesController.add(_connectedDevices);

    for (var device in _foundDevices) {
      if (device.state == SessionState.notConnected) {
        String? peerUuid = _getUuidFromDeviceName(device.deviceName);
        if (peerUuid == null) continue;

        if (Platform.isIOS && device.deviceName.startsWith("[iOS]")) {
          if (currentIOSPeers < multipeerConnectionLimit) {
            invitePeer(device);
          } else {
            // ★ CHANGE: Use the callback
            print("iOS peer limit reached. Requesting BLE connection to peer with UUID: $peerUuid");
            onBleConnectRequest(peerUuid);
          }
        }
        else if (Platform.isAndroid && device.deviceName.startsWith("[Android]")) {
            invitePeer(device);
        }
        else {
            // ★ CHANGE: Use the callback
            print("Cross-platform peer found. Requesting BLE connection to peer with UUID: $peerUuid");
            onBleConnectRequest(peerUuid);
        }
      }
    }
  }

  void startBrowsing() {
    _nearbyService.startBrowsingForPeers();
  }

  void startAdvertising() {
    _nearbyService.startAdvertisingPeer();
  }

  void invitePeer(Device device) {
    _nearbyService.invitePeer(
      deviceID: device.deviceId,
      deviceName: device.deviceName,
    );
  }

  void sendMessage(String deviceId, String message) {
    _nearbyService.sendMessage(deviceId, message);
  }

  void dispose() {
    _devicesController.close();
    _dataReceivedController.close();
    _nearbyService.stopAdvertisingPeer();
    _nearbyService.stopBrowsingForPeers();
    _nearbyService.disconnectFromAllPeers();
  }
}
