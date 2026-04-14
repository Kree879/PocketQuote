import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/quote_state.dart';
import '../state/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/feature_gate.dart';
import '../services/export_service.dart';
import '../services/onedrive_service.dart';
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
      await ExportService.exportAllDataBatch(context: context, userId: userId, currencySymbol: context.read<QuoteState>().currencySymbol);
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
    final subProvider = context.watch<SubscriptionProvider>();
    final isDark = state.isDarkMode;
    final isLoggedIn = state.currentUser != null;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('App Settings'),
            actions: [
              if (subProvider.isSubscribed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentColor, width: 1),
                      ),
                      child: Text(
                        'BUSINESS PLAN',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'FREE PLAN', 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => FeatureGate.showUpgradePath(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'UPGRADE', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: Colors.amber[600], 
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
                    Divider(height: 1, color: Theme.of(context).dividerColor.withAlpha(40)),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(state.currencyDisplayName),
                      trailing: DropdownButton<String>(
                        value: state.currencySymbol,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        underline: const SizedBox.shrink(),
                        icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).iconTheme.color?.withAlpha(178)),
                        items: const [
                          DropdownMenuItem(value: 'R', child: Text('R  (ZAR)')),
                          DropdownMenuItem(value: '\$', child: Text('\$  (USD)')),
                          DropdownMenuItem(value: '£', child: Text('£  (GBP)')),
                          DropdownMenuItem(value: '€', child: Text('€  (EUR)')),
                        ],
                        onChanged: (val) {
                          if (val != null) state.setCurrency(val);
                        },
                      ),
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
                      FeatureGate(
                        requiresBusiness: true,
                        child: ElevatedButton.icon(
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
                      FeatureGate(
                        requiresBusiness: true,
                        child: ElevatedButton.icon(
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
                        ),
                      )
                    else ...[
                      if (!state.isDriveAuthorized)
                        FeatureGate(
                          requiresBusiness: true,
                          child: ElevatedButton.icon(
                            onPressed: _isConnectingDrive ? null : () => _handleDriveConnect(context, state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: const Text('Authorize Drive Access'),
                          ),
                        )
                      else
                        FeatureGate(
                          requiresBusiness: true,
                          child: ElevatedButton.icon(
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
                        ),
                    ],
                  ],
                ),
              ),

              // OneDrive Backups
              const SizedBox(height: 32),
              Text(
                'OneDrive Backups',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your data safe by creating a dedicated backup folder in your Microsoft OneDrive.',
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
                        state.isOneDriveLinked 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                          : const Icon(Icons.cloud_upload, color: Colors.blue, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('OneDrive Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                state.isOneDriveLinked 
                                  ? 'Connected'
                                  : 'Not connected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: state.isOneDriveLinked ? Colors.green[300] : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isOneDriveLinked)
                          IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.grey),
                            onPressed: () => state.unlinkOneDrive(),
                            tooltip: 'Disconnect',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!state.isOneDriveLinked)
                      FeatureGate(
                        requiresBusiness: true,
                        child: ElevatedButton.icon(
                          onPressed: _isConnectingDrive ? null : () async {
                            setState(() => _isConnectingDrive = true);
                            final error = await state.linkOneDrive();
                            setState(() => _isConnectingDrive = false);
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to connect: $error'), backgroundColor: Colors.redAccent),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isConnectingDrive
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.window), // Windows logo approx
                          label: const Text('Connect OneDrive'),
                        ),
                      )
                    else 
                      FeatureGate(
                        requiresBusiness: true,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _isVerifyingDrive = true);
                            final folderId = await OneDriveAuthService.instance.createBackupFolder();
                            setState(() => _isVerifyingDrive = false);
                            if (context.mounted) {
                              if (folderId != null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('OneDrive Verified'),
                                    content: Text('Backup folder found/created!\n\nFolder ID: $folderId'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                    ],
                                  ),
                                );
                              } else {
                                final errorMsg = OneDriveAuthService.instance.lastError ?? 'Unknown error';
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('OneDrive Error'),
                                    content: SelectableText('Could not verify backup folder.\n\nError: $errorMsg'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
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
                      ),
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
                      FeatureGate(
                        requiresBusiness: true,
                        child: ElevatedButton.icon(
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
