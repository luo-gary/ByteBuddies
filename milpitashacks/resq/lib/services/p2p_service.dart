import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final NearbyService _nearbyService = NearbyService();
  bool _isInitialized = false;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _dataSubscription;
  final _devicesController = StreamController<List<Device>>.broadcast();
  List<Device> _connectedDevices = [];

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  List<Device> get connectedDevices => _connectedDevices;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions first
      await _requestPermissions();

      // Initialize the service
      bool initialized = await _nearbyService.init(
        serviceType: 'resq',
        strategy: Strategy.P2P_STAR,
        callback: (devicesList) {
          debugPrint('Device list updated: ${devicesList.length} devices');
          _handleDevicesUpdate(devicesList);
        },
      );

      if (!initialized) {
        throw Exception('Failed to initialize nearby service');
      }

      // Set up data received subscription
      _setupDataSubscription();

      _isInitialized = true;
      debugPrint('P2P service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing P2P service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  void _setupDataSubscription() {
    _dataSubscription?.cancel();
    _dataSubscription = _nearbyService.dataReceivedSubscription(
      callback: (deviceId, data) {
        debugPrint('Received data from $deviceId: $data');
        // Parse and handle the incoming data
        try {
          // You can parse the data here if it's JSON
          debugPrint('Successfully received data from device: $deviceId');
        } catch (e) {
          debugPrint('Error processing received data: $e');
        }
      } as DataReceivedCallback,
    );
  }

  void _handleDevicesUpdate(List<Device> devices) {
    _connectedDevices = devices.where((d) => d.state == SessionState.connected).toList();
    _devicesController.add(_connectedDevices);
    
    // Log device states
    for (var device in devices) {
      debugPrint('Device ${device.deviceId} - State: ${device.state}');
    }
  }

  Future<void> _requestPermissions() async {
    // Request location permission (required for nearby connections)
    if (!await Permission.location.isGranted) {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        throw Exception('Location permission is required for P2P communication');
      }
    }

    // Request Bluetooth permissions
    if (!await Permission.bluetooth.isGranted) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        throw Exception('Bluetooth permission is required for P2P communication');
      }
    }

    // Request Bluetooth advertise permission
    if (!await Permission.bluetoothAdvertise.isGranted) {
      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        throw Exception('Bluetooth advertise permission is required for P2P communication');
      }
    }

    // Request Bluetooth connect permission
    if (!await Permission.bluetoothConnect.isGranted) {
      final status = await Permission.bluetoothConnect.request();
      if (!status.isGranted) {
        throw Exception('Bluetooth connect permission is required for P2P communication');
      }
    }

    // Request Bluetooth scan permission
    if (!await Permission.bluetoothScan.isGranted) {
      final status = await Permission.bluetoothScan.request();
      if (!status.isGranted) {
        throw Exception('Bluetooth scan permission is required for P2P communication');
      }
    }
  }

  Future<void> startAdvertising() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      bool started = await _nearbyService.startAdvertisingPeer();
      if (!started) {
        throw Exception('Failed to start advertising');
      }
      debugPrint('Started advertising successfully');
    } catch (e) {
      debugPrint('Error starting advertising: $e');
      rethrow;
    }
  }

  Future<void> startDiscovery() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      bool started = await _nearbyService.startBrowsingForPeers();
      if (!started) {
        throw Exception('Failed to start discovery');
      }
      debugPrint('Started discovery successfully');
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      rethrow;
    }
  }

  Future<void> sendEmergencyData(String deviceId, Map<String, dynamic> data) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_connectedDevices.isEmpty) {
      debugPrint('No connected devices to send data to');
      return;
    }

    try {
      final jsonData = data.toString(); // Simple conversion for now
      bool sent = await _nearbyService.sendMessage(deviceId, jsonData);
      if (!sent) {
        throw Exception('Failed to send message to device: $deviceId');
      }
      debugPrint('Emergency data sent successfully to device: $deviceId');
    } catch (e) {
      debugPrint('Error sending emergency data: $e');
      rethrow;
    }
  }

  Future<void> stopAllEndpoints() async {
    if (!_isInitialized) return;

    try {
      await _nearbyService.stopBrowsingForPeers();
      await _nearbyService.stopAdvertisingPeer();
      _connectedDevices.clear();
      _devicesController.add(_connectedDevices);
      _isInitialized = false;
      debugPrint('All P2P endpoints stopped');
    } catch (e) {
      debugPrint('Error stopping P2P endpoints: $e');
      rethrow;
    }
  }

  void dispose() {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    _devicesController.close();
    stopAllEndpoints();
  }
} 