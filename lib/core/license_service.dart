import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._();
  LicenseService._();

  static const String _keyToken = 'license_token';
  static const String _keyHwid = 'license_hwid';

  /// Get unique hardware ID for this computer
  Future<String> getHardwareId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final windowsInfo = await deviceInfo.windowsInfo;

      // Combine multiple hardware identifiers for uniqueness
      final hwString =
          '${windowsInfo.computerName}'
          '${windowsInfo.numberOfCores}'
          '${windowsInfo.systemMemoryInMegabytes}';

      // Hash the hardware string for security
      final bytes = utf8.encode(hwString);
      final digest = sha256.convert(bytes);

      return digest.toString();
    } catch (e) {
      debugPrint('Error getting hardware ID: $e');
      // Fallback to a simple identifier
      return 'UNKNOWN_HWID';
    }
  }

  /// Activate the license with a token
  Future<bool> activate(String token) async {
    if (token.trim().isEmpty) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hwid = await getHardwareId();

      // Save token and HWID
      await prefs.setString(_keyToken, token.trim());
      await prefs.setString(_keyHwid, hwid);

      debugPrint('License activated successfully');
      return true;
    } catch (e) {
      debugPrint('Error activating license: $e');
      return false;
    }
  }

  /// Check if the license is activated and valid
  Future<bool> isActivated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      final savedHwid = prefs.getString(_keyHwid);

      // No license saved
      if (savedToken == null || savedHwid == null) {
        debugPrint('No license found');
        return false;
      }

      // Get current HWID
      final currentHwid = await getHardwareId();

      // Check if HWID matches (prevents copying to another computer)
      if (savedHwid != currentHwid) {
        debugPrint('HWID mismatch - license invalid on this computer');
        return false;
      }

      debugPrint('License is valid');
      return true;
    } catch (e) {
      debugPrint('Error checking license: $e');
      return false;
    }
  }

  /// Get the current activation token (for display purposes)
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// Deactivate the license (for testing/admin purposes)
  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyHwid);
    debugPrint('License deactivated');
  }
}
