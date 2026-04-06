import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// A custom HTTP client that injects auth headers into every request.
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Map<String, String> _headers;

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// Service that handles Google Sign-In and Google Drive API operations.
class GoogleDriveAuthService {
  GoogleDriveAuthService._();
  static final GoogleDriveAuthService instance = GoogleDriveAuthService._();

  static const String _driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const List<String> _scopes = <String>[_driveFileScope];
  static const String backupFolderName = 'Pocket Quote Backups';
  
  // Client IDs provided by user
  static const String _clientId = '597608208696-3dad01ns1r4l6k1c0b86n43kplhn35l3.apps.googleusercontent.com';
  static const String _serverClientId = '597608208696-3dad01ns1r4l6k1c0b86n43kplhn35l3.apps.googleusercontent.com';

  GoogleSignInAccount? _currentUser;
  Map<String, String>? _authHeaders;
  bool _initialized = false;

  bool get isSignedIn => _currentUser != null;
  bool get isAuthorized => _authHeaders != null;
  GoogleSignInAccount? get currentUser => _currentUser;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      serverClientId: _serverClientId,
    );

    // Try silent / lightweight sign-in (restores previous session)
    _currentUser = await signIn.attemptLightweightAuthentication();
    
    // If successfully restored, we should authorize to get fresh headers
    if (_currentUser != null) {
      await _requestAuthorization();
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-In / Sign-Out
  // ---------------------------------------------------------------------------

  /// Requests the user's identity then authorizes the Drive scope.
  Future<bool> _requestAuthorization() async {
    if (_currentUser == null) return false;
    try {
      final authorization = await _currentUser!.authorizationClient.authorizeScopes(_scopes);
      _authHeaders = {
        'Authorization': 'Bearer ${authorization.accessToken}',
      };
      return true;
          return false;
    } catch (e) {
      debugPrint('GoogleDriveAuthService: authorization failed — $e');
      return false;
    }
  }

  /// Triggers the interactive Google Sign-In flow.
  /// 
  /// Returns null on success, or a descriptive error message on failure.
  Future<String?> signInWithGoogle() async {
    try {
      if (!_initialized) await initialize();
      
      final signIn = GoogleSignIn.instance;
      
      // 1. Authenticate (who is the user?)
      final account = await signIn.authenticate();

      _currentUser = account;
      
      // 2. Authorize (can we access Drive?)
      final authorized = await _requestAuthorization();
      if (!authorized) {
        return 'Permission to access Google Drive was not granted.';
      }

      return null; // Success
    } on GoogleSignInException catch (e) {
      final logMsg = 'GoogleSignInException: code=${e.code}';
      debugPrint('GoogleDriveAuthService: connection error — $logMsg');
      return 'Configuration Error (Code ${e.code}). Please check your settings.';
    } catch (e) {
      debugPrint('GoogleDriveAuthService: unexpected sign-in failed — $e');
      if (e.toString().contains('network_error')) {
        return 'Network error. Please check your connection.';
      }
      return e.toString();
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('GoogleDriveAuthService: sign-out failed — $e');
    }
    _currentUser = null;
    _authHeaders = null;
  }

  // ---------------------------------------------------------------------------
  // Drive Integration
  // ---------------------------------------------------------------------------

  /// Create a DriveApi instance using the custom AuthenticatedClient.
  drive.DriveApi _getDriveApi() {
    if (_authHeaders == null) {
      throw StateError('User not authorized. Call signInWithGoogle() first.');
    }
    final client = AuthenticatedClient(_authHeaders!);
    return drive.DriveApi(client);
  }

  /// Creates or finds the backup folder.
  Future<String?> createBackupFolder() async {
    try {
      final driveApi = _getDriveApi();

      final existingId = await _findBackupFolder(driveApi);
      if (existingId != null) return existingId;

      final folderMetadata = drive.File()
        ..name = backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await driveApi.files.create(folderMetadata);
      return created.id;
    } catch (e) {
      debugPrint('GoogleDriveAuthService: failed to create folder — $e');
      return null;
    }
  }

  Future<String?> _findBackupFolder(drive.DriveApi driveApi) async {
    final query = "name = '$backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final result = await driveApi.files.list(q: query, spaces: 'drive');
    final files = result.files;
    return (files != null && files.isNotEmpty) ? files.first.id : null;
  }

  /// Uploads a file to the backup folder.
  /// Defaults to the user-provided folder ID '1eufszFfuDyDAsRiU8ECv3vxRZFwbynKK'.
  Future<String?> uploadFile({
    required Uint8List data,
    required String fileName,
    required String mimeType,
    String? folderId,
  }) async {
    try {
      final driveApi = _getDriveApi();
      final targetFolderId = folderId ?? await createBackupFolder() ?? '1eufszFfuDyDAsRiU8ECv3vxRZFwbynKK';

      final fileMetadata = drive.File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = [targetFolderId];

      final media = drive.Media(Stream.value(data), data.length);
      final created = await driveApi.files.create(fileMetadata, uploadMedia: media);
      
      return created.id;
    } catch (e) {
      debugPrint('GoogleDriveAuthService: upload failed — $e');
      return null;
    }
  }

  void dispose() {

    _initialized = false;
  }
}
