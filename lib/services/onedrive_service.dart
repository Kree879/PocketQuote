import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:http/http.dart' as http;
import '../main.dart'; // To access globalNavigatorKey

class OneDriveAuthService {
  OneDriveAuthService._();
  static final OneDriveAuthService instance = OneDriveAuthService._();

  AadOAuth? _oauth;
  String? _accessToken;
  bool _initialized = false;

  bool get isSignedIn => _accessToken != null;

  void initialize() {
    if (_initialized) return;
    
    final Config config = Config(
      tenant: 'f6045e80-467d-4a32-bc60-21e46074a44f',
      clientId: '8022017f-dce9-4005-8cdb-0580f5baedc8',
      scope: 'openid profile offline_access Files.ReadWrite.AppFolder',
      redirectUri: 'https://login.live.com/oauth20_desktop.srf',
      navigatorKey: globalNavigatorKey,
    );

    _oauth = AadOAuth(config);
    _initialized = true;
  }

  /// Triggers the Microsoft OAuth popup
  Future<String?> signInWithMicrosoft() async {
    try {
      if (!_initialized) initialize();
      
      await _oauth!.login();
      _accessToken = await _oauth!.getAccessToken();
      
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        return null; // Success
      } else {
        return 'Microsoft authentication cancelled or failed.';
      }
    } catch (e) {
      debugPrint('OneDriveAuthService error: $e');
      return e.toString();
    }
  }

  Future<void> signOut() async {
    if (!_initialized) initialize();
    await _oauth!.logout();
    _accessToken = null;
  }

  /// Uploads a file directly to the special App Root in OneDrive
  /// Note: The AppFolder scope automatically maps to /Apps/[AppName]/...
  Future<bool> uploadFile({
    required Uint8List data,
    required String fileName,
  }) async {
    if (_accessToken == null) return false;

    try {
      // Graph API for App Root Folder
      final String url = 'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$fileName:/content';
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/pdf', // Assuming PDF here, but can be dynamic
        },
        body: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OneDrive upload success: ${response.statusCode}');
        return true;
      } else {
        debugPrint('OneDrive upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('OneDriveAuthService upload exception: $e');
      return false;
    }
  }
}
