import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// Handles iOS-specific permission requests
class PermissionUtil {
  static String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.microphone:
        return 'Microphone';
      case Permission.locationWhenInUse:
        return 'Location';
      case Permission.bluetoothScan:
        return 'Bluetooth';
      default:
        return permission.toString();
    }
  }

  /// Request all required iOS permissions
  static Future<void> requestIosPermissions(BuildContext context) async {
    if (!Platform.isIOS) return;

    // 1) fire all requests off in parallel
    final statuses = await Future.wait([
      Permission.camera.request(),
      Permission.microphone.request(),
      Permission.locationWhenInUse.request(),
    ]);

    // 2) if *any* is permanentlyDenied, direct user to Settings
    if (statuses.any((s) => s.isPermanentlyDenied)) {
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'Open Settings → ResQ Link and enable Camera, Microphone & Location.',
          ),
          actions: [
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
            ),
          ],
        ),
      );
      return;
    }

    // 3) at this point camera/mic/location are either .granted or (for location) .limited
    // The calling screen should check individual permission states before using features
  }
} 