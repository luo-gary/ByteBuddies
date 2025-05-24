import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_data.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final Nearby _nearby = Nearby();
  bool _isInitialized = false;
  StreamController<String>? _stateController;
  final Set<String> _connectedEndpoints = {};

  final String _serviceId = 'com.resqlink.emergency';
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request necessary permissions
      await _requestPermissions();

      // Initialize state controller
      _stateController = StreamController<String>.broadcast();
      _stateController?.stream.listen(
        (state) {
          debugPrint('Nearby Connections state changed: $state');
        },
        onError: (error) {
          debugPrint('Nearby Connections error: $error');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing P2P service: $e');
      _isInitialized = false;
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
      bool started = await _nearby.startAdvertising(
        'device-${DateTime.now().millisecondsSinceEpoch}',
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      debugPrint('Advertising ${started ? 'started' : 'failed to start'}');
    } catch (e) {
      debugPrint('Error starting advertising: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      bool started = await _nearby.startDiscovery(
        'device-${DateTime.now().millisecondsSinceEpoch}',
        _strategy,
        onEndpointFound: (String id, String userName, String serviceId) {
          debugPrint('Found endpoint: $id, user: $userName, service: $serviceId');
          _onEndpointFound(id, userName, serviceId);
        },
        onEndpointLost: (id) => debugPrint('Lost endpoint: $id'),
        serviceId: _serviceId,
      );

      debugPrint('Discovery ${started ? 'started' : 'failed to start'}');
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    debugPrint('Connection initiated with device: $id');
    _nearby.acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String id, Status status) {
    debugPrint('Connection result with device $id: $status');
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(id);
    } else {
      _connectedEndpoints.remove(id);
    }
  }

  void _onDisconnected(String id) {
    debugPrint('Disconnected from device: $id');
    _connectedEndpoints.remove(id);
  }

  void _onEndpointFound(String id, String userName, String serviceId) {
    _nearby.requestConnection(
      'device-${DateTime.now().millisecondsSinceEpoch}',
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onPayloadReceived(String id, Payload payload) {
    debugPrint('Received payload from $id: ${payload.type}');
  }

  void _onPayloadTransferUpdate(String id, PayloadTransferUpdate update) {
    debugPrint('Payload transfer update from $id: ${update.status}');
  }

  Future<void> stopAllEndpoints() async {
    if (!_isInitialized) return;

    try {
      await _nearby.stopAllEndpoints();
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _stateController?.close();
      _stateController = null;
      _connectedEndpoints.clear();
      _isInitialized = false;
      debugPrint('All P2P endpoints stopped');
    } catch (e) {
      debugPrint('Error stopping endpoints: $e');
    }
  }

  Future<void> sendEmergencyData(Map<String, dynamic> data) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_connectedEndpoints.isEmpty) {
      debugPrint('No connected endpoints to send data to');
      return;
    }

    try {
      final bytes = Uint8List.fromList(data.toString().codeUnits);
      for (final endpointId in _connectedEndpoints) {
        await _nearby.sendBytesPayload(endpointId, bytes);
        debugPrint('Emergency data sent to endpoint: $endpointId');
      }
    } catch (e) {
      debugPrint('Error sending emergency data: $e');
    }
  }
} 