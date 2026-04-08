import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/quote_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../services/export_service.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isConnectingDrive = false;
  bool _isVerifyingDrive = false;

  Future<void> _handleExport(BuildContext context, String userId) async {
    setState(() => _isExporting = true);
    try {
      // Use the new Batch Drive export (Catalog + History)
      await ExportService.exportAllDataBatch(context: context, userId: userId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }


  Future<void> _handleSyncNow(BuildContext context, QuoteState state) async {

    try {
      await state.syncAllLocalDataToCloud();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data synced successfully to the cloud!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDriveConnect(BuildContext context, QuoteState state) async {
    setState(() => _isConnectingDrive = true);
    try {
      final error = await state.linkGoogleDrive();
      if (context.mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Drive connected!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection failed: $error'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingDrive = false);
    }
  }

  Future<void> _handleDriveVerify(BuildContext context, QuoteState state) async {
    setState(() => _isVerifyingDrive = true);
    try {
      final folderId = await state.createDriveBackupFolder();
      if (context.mounted) {
        if (folderId != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Connection Verified'),
              content: Text('Backup folder found or created successfully!\n\nFolder ID: $folderId'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to verify folder. Please check your permissions.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingDrive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<QuoteState>();
    final isDark = state.isDarkMode;
    final isLoggedIn = state.currentUser != null;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('App Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'App Appearance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize how Pocket Quote looks on your device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              
              GlassContainer(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(isDark ? 'Professional Navy Theme' : 'Clean Light Theme'),
                      value: isDark,
                      onChanged: (val) {
                        state.toggleThemeMode();
                      },
                      activeThumbColor: AppTheme.accentColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ],
                ),
              ),

              // Cloud Sync (Firestore)
              if (isLoggedIn) ...[
                const SizedBox(height: 32),
                Text(
                  'Cloud Sync',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Force-push all local quotes and settings to the cloud. Use this if data is missing after a permission change.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_sync_outlined, color: AppTheme.accentColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  'Logged in as ${state.currentUser!.email ?? "Unknown"}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: state.isSyncing ? null : () => _handleSyncNow(context, state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: state.isSyncing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(state.isSyncing ? 'Syncing...' : 'Push All Data to Cloud'),
                      ),
                      if (state.lastSyncedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last synced: ${DateFormat('MMM dd, HH:mm').format(state.lastSyncedAt!)}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Google Drive Backups
              const SizedBox(height: 32),
              Text(
                'Google Drive Backups',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your data safe by creating a dedicated backup folder in your Google Drive. We only access files we create.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        state.isDriveLinked 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                          : const Icon(Icons.add_to_drive, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Google Drive Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                state.isDriveLinked 
                                  ? state.driveUserEmail ?? "Connected"
                                  : 'Not connected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: state.isDriveLinked ? Colors.green[300] : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isDriveLinked)
                          IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.grey),
                            onPressed: () => state.unlinkGoogleDrive(),
                            tooltip: 'Disconnect',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!state.isDriveLinked)
                      ElevatedButton.icon(
                        onPressed: _isConnectingDrive ? null : () => _handleDriveConnect(context, state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isConnectingDrive
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: const Text('Connect Google Drive'),
                      )
                    else ...[
                      if (!state.isDriveAuthorized)
                        ElevatedButton.icon(
                          onPressed: _isConnectingDrive ? null : () => _handleDriveConnect(context, state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.vpn_key_outlined),
                          label: const Text('Authorize Drive Access'),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isVerifyingDrive ? null : () => _handleDriveVerify(context, state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isVerifyingDrive
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Verify Backup Folder'),
                        ),
                    ],
                  ],
                ),
              ),

              // CSV Export
              if (isLoggedIn) ...[
                const SizedBox(height: 32),
                Text(
                  'Export Data',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download all your Jobs and Catalog items as a CSV file, ready to open in Excel or Google Sheets.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.table_chart_outlined, color: AppTheme.accentColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Export to CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  'Includes all Pocket Quote quotes and catalog items. Dates formatted YYYY-MM-DD.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : () => _handleExport(context, state.currentUser!.uid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isExporting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download_outlined),
                        label: Text(_isExporting ? 'Exporting...' : 'Export All Data (.csv)'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmClearData(context),
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text('Clear All Saved Quotes', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
        
        // Syncing Overlay
        if (state.isSyncing)
          Container(
            color: Colors.black54,
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    const Text(
                      'Syncing Data...',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This may take a moment.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Exporting Overlay
        if (_isExporting)
          Container(
            color: Colors.black54,
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 24),
                    const Text(
                      'Syncing Data...',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pocket Quote is backing up your data.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }


  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all saved quotes, history, and associated photos. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<QuoteState>().clearAllData();
              Navigator.pop(context);
              Navigator.pop(context); // Back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear Everything', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
