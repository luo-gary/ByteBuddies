import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/emergency_data.dart';

class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final Nearby _nearby = Nearby();
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  static const String _strategy = Strategy.P2P_STAR;
  static const String _serviceId = 'com.resqlink.emergency';

  Future<bool> startAdvertising() async {
    if (_isAdvertising) return true;

    try {
      bool permissionGranted = await _nearby.askLocationPermission();
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
      bool permissionGranted = await _nearby.askLocationPermission();
      if (!permissionGranted) return false;

      await _nearby.startDiscovery(
        'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
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
      _sendUnsentEmergencyData(id);
    }
  }

  void _onDisconnected(String id) {
    print('Disconnected from: $id');
  }

  void _onEndpointFound(String id, String userName, String serviceId) {
    _nearby.requestConnection(
      'DEVICE_${DateTime.now().millisecondsSinceEpoch}',
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onEndpointLost(String id) {
    print('Lost endpoint: $id');
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
    _isAdvertising = false;
    _isDiscovering = false;
  }
} 