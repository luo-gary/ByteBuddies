import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_data.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final Nearby _nearby = Nearby();
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Set<String> _connectedPeers = {};

  static const Strategy _strategy = Strategy.P2P_STAR;
  static const String _serviceId = 'com.resqlink.emergency';

  Future<bool> startAdvertising() async {
    if (_isAdvertising) return true;

    try {
      bool permissionGranted = await Permission.location.request().isGranted;
      if (!permissionGranted) return false;

      await _nearby.startAdvertising(
        'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      _isAdvertising = true;
      return true;
    } catch (e) {
      print('Error starting advertising: $e');
      return false;
    }
  }

  Future<bool> startDiscovery() async {
    if (_isDiscovering) return true;

    try {
      bool permissionGranted = await Permission.location.request().isGranted;
      if (!permissionGranted) return false;

      await _nearby.startDiscovery(
        'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
        _strategy,
        onEndpointFound: (String id, String name, String serviceId) {
          _onEndpointFound(id, name, serviceId);
        },
        onEndpointLost: (id) => print('Lost endpoint: $id'),
        serviceId: _serviceId,
      );

      _isDiscovering = true;
      return true;
    } catch (e) {
      print('Error starting discovery: $e');
      return false;
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    _nearby.acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _connectedPeers.add(id);
      _sendUnsentEmergencyData(id);
    } else if (status == Status.REJECTED || status == Status.ERROR) {
      _connectedPeers.remove(id);
    }
  }

  void _onDisconnected(String id) {
    _connectedPeers.remove(id);
    print('Disconnected from: $id');
  }

  void _onEndpointFound(String id, String name, String serviceId) {
    _nearby.requestConnection(
      'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onPayloadReceived(String id, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      String dataString = String.fromCharCodes(payload.bytes!);
      Map<String, dynamic> json = jsonDecode(dataString);
      EmergencyData emergencyData = EmergencyData.fromJson(json);
      EmergencyData.saveEmergencyData(emergencyData);
    }
  }

  void _onPayloadTransferUpdate(String id, PayloadTransferUpdate update) {
    if (update.status == PayloadStatus.SUCCESS) {
      print('Payload transfer successful');
    }
  }

  Future<void> _sendUnsentEmergencyData(String endpointId) async {
    List<EmergencyData> unsentData = await EmergencyData.getUnsentEmergencyData();
    for (var data in unsentData) {
      try {
        await _nearby.sendBytesPayload(
          endpointId,
          Uint8List.fromList(jsonEncode(data.toJson()).codeUnits),
        );
        await data.markAsSent();
      } catch (e) {
        print('Error sending emergency data: $e');
      }
    }
  }

  Future<void> broadcastEmergencyData(EmergencyData data) async {
    try {
      // Send to all connected peers
      for (var endpointId in _connectedPeers) {
        try {
          await _nearby.sendBytesPayload(
            endpointId,
            Uint8List.fromList(jsonEncode(data.toJson()).codeUnits),
          );
        } catch (e) {
          print('Error sending to endpoint $endpointId: $e');
          // Remove the peer if we can't send to it
          _connectedPeers.remove(endpointId);
        }
      }
    } catch (e) {
      print('Error broadcasting emergency data: $e');
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    await _nearby.stopAdvertising();
    _isAdvertising = false;
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  Future<void> stopAllEndpoints() async {
    await _nearby.stopAllEndpoints();
    _connectedPeers.clear();
    _isAdvertising = false;
    _isDiscovering = false;
  }
} 