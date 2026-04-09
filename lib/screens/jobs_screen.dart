import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../state/quote_state.dart';
import '../models/quote_model.dart';
import '../widgets/job_card.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../services/pdf_service.dart';
import '../services/google_drive_auth_service.dart';
import '../services/onedrive_service.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  QuoteStatus? _selectedFilter; // null means 'All'
  final Set<String> _selectedIds = {};
  bool _isBackingUp = false;
  int _backupCount = 0;

  Future<void> _handleBackupSelected(List<QuoteModel> history, QuoteState state) async {
    final driveService = GoogleDriveAuthService.instance;
    final oneDriveService = OneDriveAuthService.instance;
    
    if (!driveService.isAuthorized && !oneDriveService.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cloud drives connected. Please link Google Drive or OneDrive in settings.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() {
      _isBackingUp = true;
      _backupCount = _selectedIds.length;
    });

    int successCount = 0;
    int errorCount = 0;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (String id in _selectedIds) {
        final quote = history.firstWhere((q) => q.id == id);
        
        try {
          final isInvoice = quote.status == QuoteStatus.completed || 
                            quote.status == QuoteStatus.invoiced || 
                            quote.status == QuoteStatus.paid;
                            
          final bytes = await PdfService.generateQuotePDF(
            quote: quote,
            globalState: state,
            isInvoice: isInvoice,
          );

          final jobName = quote.projectTitle.isNotEmpty ? quote.projectTitle : 
                         (quote.clientName.isNotEmpty ? quote.clientName : "Project");
          final safeJobName = jobName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').replaceAll(' ', '_');
          final fileName = "${safeJobName}_${dateStr}_Quote.pdf";

          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);
          final fileBytes = await tempFile.readAsBytes();

          bool uploadedToAtLeastOne = false;

          // Try Google Drive Backup
          if (driveService.isAuthorized) {
            final fileId = await driveService.uploadFile(
              data: fileBytes,
              fileName: fileName,
              mimeType: 'application/pdf',
            );
            if (fileId != null) uploadedToAtLeastOne = true;
          }

          // Try OneDrive Backup
          if (oneDriveService.isSignedIn) {
            final success = await oneDriveService.uploadFile(
              data: fileBytes, 
              fileName: fileName,
            );
            if (success) uploadedToAtLeastOne = true;
          }

          if (uploadedToAtLeastOne) {
            successCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          debugPrint('Error backing up quote ${quote.id}: $e');
          errorCount++;
        }
      }
      
      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully backed up $successCount jobs to Drive.'), backgroundColor: Colors.green),
          );
        }
        if (errorCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to backup $errorCount jobs.'), backgroundColor: Colors.redAccent),
          );
        }
        
        if (errorCount == 0) {
          setState(() {
            _selectedIds.clear();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Manager'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<QuoteState>(
        builder: (context, state, child) {
          final history = state.jobHistory;
          
          final filteredJobs = _selectedFilter == null 
              ? history 
              : history.where((q) => q.status == _selectedFilter).toList();

          // Count totals
          int countAll = history.length;

          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('$countAll jobs total', style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              
              // Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Select All
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: filteredJobs.isNotEmpty && _selectedIds.length == filteredJobs.length,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.addAll(filteredJobs.map((q) => q.id));
                                } else {
                                  _selectedIds.clear();
                                }
                              });
                            },
                            activeColor: AppTheme.accentColor,
                            side: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Select all (${filteredJobs.length})', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    
                    Row(
                      children: [
                        if (_selectedIds.isNotEmpty) ...[
                          IconButton(
                            onPressed: () => _handleBackupSelected(history, context.read<QuoteState>()),
                            icon: Icon(Icons.cloud_upload_outlined, color: AppTheme.accentColor, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.accentColor.withAlpha(20),
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            tooltip: 'Backup',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  title: const Text('Delete Selected'),
                                  content: Text('Delete ${_selectedIds.length} quote(s)?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        final qs = context.read<QuoteState>();
                                        for (String id in _selectedIds.toList()) {
                                          final q = history.firstWhere((q) => q.id == id);
                                          if (q.firestoreId != null) {
                                            qs.deleteQuoteFromCloud(q.firestoreId!);
                                          } else {
                                            qs.deleteQuote(q.id);
                                          }
                                        }
                                        setState(() {
                                          _selectedIds.clear();
                                        });
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withAlpha(20),
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            tooltip: 'Delete',
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        // Filter Dropdown
                        PopupMenuButton<int>(
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(12),
                             side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.filter_alt_outlined, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                                const SizedBox(width: 6),
                                Text('Filter Jobs', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                              ],
                            ),
                          ),
                          onSelected: (int result) {
                            setState(() {
                              if (result == -1) {
                                _selectedFilter = null;
                              } else {
                                _selectedFilter = QuoteStatus.values[result];
                              }
                              _selectedIds.clear(); 
                            });
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                            PopupMenuItem(
                              value: -1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text('All', style: Theme.of(context).textTheme.bodyLarge),
                                      if (_selectedFilter == null) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.check, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                                      ]
                                    ],
                                  ),
                                  Text('$countAll', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            ...[
                              QuoteStatus.sent,
                              QuoteStatus.approved,
                              QuoteStatus.inProgress,
                              QuoteStatus.completed,
                              QuoteStatus.invoiced,
                              QuoteStatus.paid,
                            ].map((status) {
                              int count = history.where((q) => q.status == status).length;
                              String label = status == QuoteStatus.sent ? 'Quoted' : 
                                             (status == QuoteStatus.inProgress ? 'In Progress' : 
                                             status.name[0].toUpperCase() + status.name.substring(1));
                              return PopupMenuItem(
                                value: status.index,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(label, style: Theme.of(context).textTheme.bodyLarge),
                                        if (_selectedFilter == status) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.check, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                                        ]
                                      ]
                                    ),
                                    Text('$count', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Job List
              Expanded(
                child: filteredJobs.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == null ? 'No jobs found.' : 'No jobs with selected status.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: filteredJobs.length,
                        itemBuilder: (context, index) {
                          final job = filteredJobs[index];
                          return JobCard(
                            quote: job,
                            isSelected: _selectedIds.contains(job.id),
                            onSelectionChanged: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.add(job.id);
                                } else {
                                  _selectedIds.remove(job.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
              if (_isBackingUp)
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
                          Text(
                            'Uploading $_backupCount Jobs to Drive...',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Do not close the application.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
