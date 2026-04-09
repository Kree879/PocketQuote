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

  static const String backupFolderName = 'Pocket Quote Backups';

  AadOAuth? _oauth;
  String? _accessToken;
  bool _initialized = false;

  /// Track last error for UI display
  String? lastError;

  bool get isSignedIn => _accessToken != null && _accessToken!.isNotEmpty;

  void initialize() {
    if (_initialized) return;
    
    final Config config = Config(
      tenant: 'f6045e80-467d-4a32-bc60-21e46074a44f',
      clientId: '8022017f-dce9-4005-8cdb-0580f5baedc8',
      scope: 'openid profile offline_access https://graph.microsoft.com/Files.ReadWrite',
      redirectUri: 'https://login.live.com/oauth20_desktop.srf',
      navigatorKey: globalNavigatorKey,
    );

    _oauth = AadOAuth(config);
    _initialized = true;
  }

  /// Returns a usable token. Tries to refresh, but falls back to stored token.
  Future<String?> _getUsableToken() async {
    // First try refreshing from the OAuth library
    if (_oauth != null) {
      try {
        final fresh = await _oauth!.getAccessToken();
        if (fresh != null && fresh.isNotEmpty) {
          _accessToken = fresh;
          debugPrint('OneDrive: refreshed token successfully');
          return _accessToken;
        }
      } catch (e) {
        debugPrint('OneDrive: token refresh threw: $e — falling back to stored token');
      }
    }
    // Fall back to the token we stored during login
    return _accessToken;
  }

  /// Triggers the Microsoft OAuth popup
  Future<String?> signInWithMicrosoft() async {
    try {
      if (!_initialized) initialize();
      
      await _oauth!.login();
      _accessToken = await _oauth!.getAccessToken();
      
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        debugPrint('OneDrive: login success, token length=${_accessToken!.length}');
        return null; // Success
      } else {
        lastError = 'Microsoft authentication cancelled or failed.';
        return lastError;
      }
    } catch (e) {
      debugPrint('OneDriveAuthService error: $e');
      lastError = e.toString();
      return lastError;
    }
  }

  Future<void> signOut() async {
    if (!_initialized) initialize();
    try {
      await _oauth!.logout();
    } catch (e) {
      debugPrint('OneDrive: logout error — $e');
    }
    _accessToken = null;
    lastError = null;
  }

  /// Creates the backup folder if it doesn't exist. Returns the folder ID.
  /// Returns null on failure and populates [lastError] with the reason.
  Future<String?> createBackupFolder() async {
    final token = await _getUsableToken();
    if (token == null || token.isEmpty) {
      lastError = 'No valid access token. Please reconnect OneDrive.';
      debugPrint('OneDrive: $lastError');
      return null;
    }

    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Step 1: List root children and look for our folder
      debugPrint('OneDrive: checking for existing backup folder...');
      final listUrl = Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root/children');
      final listResponse = await http.get(listUrl, headers: headers);
      
      debugPrint('OneDrive: list root children → ${listResponse.statusCode}');

      if (listResponse.statusCode == 401) {
        lastError = 'Access token expired or invalid (401). Please disconnect and reconnect OneDrive.';
        debugPrint('OneDrive: $lastError');
        debugPrint('OneDrive: response body → ${listResponse.body}');
        return null;
      }

      if (listResponse.statusCode == 200) {
        final data = json.decode(listResponse.body);
        final children = data['value'] as List? ?? [];
        debugPrint('OneDrive: found ${children.length} items in root');
        
        for (var child in children) {
          if (child['name'] == backupFolderName && child['folder'] != null) {
            final id = child['id'] as String;
            debugPrint('OneDrive: backup folder already exists → $id');
            lastError = null;
            return id;
          }
        }
        debugPrint('OneDrive: backup folder not found, will create it');
      } else {
        lastError = 'Failed to list OneDrive root (${listResponse.statusCode}): ${listResponse.body}';
        debugPrint('OneDrive: $lastError');
        return null;
      }

      // Step 2: Create the folder
      debugPrint('OneDrive: creating "$backupFolderName" folder...');
      final createUrl = Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root/children');
      final createResponse = await http.post(
        createUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': backupFolderName,
          'folder': {},
          '@microsoft.graph.conflictBehavior': 'fail',
        }),
      );

      debugPrint('OneDrive: create folder → ${createResponse.statusCode}');
      debugPrint('OneDrive: create body → ${createResponse.body}');

      if (createResponse.statusCode == 201) {
        final data = json.decode(createResponse.body);
        lastError = null;
        return data['id'] as String;
      }

      // 409 = already exists (race condition) — try listing again
      if (createResponse.statusCode == 409) {
        debugPrint('OneDrive: 409 conflict — folder already exists, re-listing...');
        final retryResponse = await http.get(listUrl, headers: headers);
        if (retryResponse.statusCode == 200) {
          final data = json.decode(retryResponse.body);
          final children = data['value'] as List? ?? [];
          for (var child in children) {
            if (child['name'] == backupFolderName && child['folder'] != null) {
              lastError = null;
              return child['id'] as String;
            }
          }
        }
      }

      lastError = 'Folder creation failed (${createResponse.statusCode}): ${createResponse.body}';
      debugPrint('OneDrive: $lastError');
      return null;
    } catch (e) {
      lastError = 'Exception during folder creation: $e';
      debugPrint('OneDrive: $lastError');
      return null;
    }
  }

  /// Uploads a file to the "Pocket Quote Backups" folder using path-based PUT.
  Future<bool> uploadFile({
    required Uint8List data,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    final token = await _getUsableToken();
    if (token == null || token.isEmpty) {
      lastError = 'No valid token for upload';
      debugPrint('OneDrive: $lastError');
      return false;
    }

    try {
      // Ensure the backup folder exists
      final folderId = await createBackupFolder();
      if (folderId == null) {
        // lastError already set by createBackupFolder
        return false;
      }

      // Use path-based upload: /root:/FolderName/FileName:/content
      final encodedFileName = Uri.encodeComponent(fileName);
      final url = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/$backupFolderName/$encodedFileName:/content',
      );

      debugPrint('OneDrive: uploading "$fileName" (${data.length} bytes)...');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': mimeType,
        },
        body: data,
      );

      debugPrint('OneDrive: upload → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('OneDrive: upload success ✓');
        lastError = null;
        return true;
      } else {
        lastError = 'Upload failed (${response.statusCode}): ${response.body}';
        debugPrint('OneDrive: $lastError');
        return false;
      }
    } catch (e) {
      lastError = 'Upload exception: $e';
      debugPrint('OneDrive: $lastError');
      return false;
    }
  }
}
