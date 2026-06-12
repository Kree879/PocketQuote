import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/receipt_scanner_service.dart';
import '../state/subscription_provider.dart';
import '../widgets/feature_gate.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';



class ReceiptScannerSheet extends StatefulWidget {
  final String quoteId;
  final Map<String, dynamic>? initialData;
  final File? initialImage;
  final bool autoScan;
  final bool manualMode;

  const ReceiptScannerSheet({
    super.key, 
    required this.quoteId,
    this.initialData,
    this.initialImage,
    this.autoScan = false,
    this.manualMode = false,
  });

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  bool _showForm = false;
  bool _isScanning = false;
  
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedCategory;
  File? _receiptImage;
  List<dynamic>? _extractedItems;
  
  final List<String> _defaultCategories = [
    'Materials', 'Labor', 'Fuel', 'Tools', 'Subcontractor', 'Other'
  ];
  List<String> _recentCategories = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadRecentCategories();

    if (widget.initialData != null || widget.initialImage != null) {
      _receiptImage = widget.initialImage;
      if (widget.initialData != null) {
        final data = widget.initialData!;
        // Harden Field Mapping: Handle various potential keys from AI results
        _vendorController.text = (data['merchantName'] ?? data['vendorName'] ?? data['vendor'] ?? data['merchant'] ?? '')?.toString() ?? '';
        _dateController.text = data['date']?.toString() ?? _dateController.text;
        _amountController.text = (data['totalAmount'] ?? data['amount'] ?? data['total'] ?? '')?.toString() ?? '';
        _extractedItems = data['items'] as List<dynamic>?;
      }
      _showForm = true;
    }

    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _takePhotoAndProcess();
      });
    } else if (widget.manualMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleManualEntry();
      });
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentCategories() async {
    // SharedPreferences memory logic: Load the previously saved list of 
    // recent categories (up to 3) from local storage.
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentCategories = prefs.getStringList('recent_receipt_categories') ?? [];
    });
  }

  Future<void> _saveRecentCategory(String category) async {
    // SharedPreferences memory logic: Save the newly selected category.
    // It's placed at the start of the list. We ensure uniqueness by removing 
    // it first if it exists, and then we cap the list length at 3.
    final prefs = await SharedPreferences.getInstance();
    List<String> recents = prefs.getStringList('recent_receipt_categories') ?? [];
    
    // Remove if exists to move to top
    recents.remove(category);
    recents.insert(0, category);
    
    // Keep only last 3
    if (recents.length > 3) {
      recents = recents.sublist(0, 3);
    }
    
    await prefs.setStringList('recent_receipt_categories', recents);
    setState(() {
      _recentCategories = recents;
    });
  }

  Future<void> _takePhotoAndProcess() async {
    // Defence-in-depth: guard AI scanning even if call site omits a FeatureGate.
    final sub = context.read<SubscriptionProvider>();
    if (!sub.isSubscribed) {
      FeatureGate.showUpgradePath(context);
      return;
    }

    final source = await _showImageSourceDialog();
    if (source == null) return;

    final service = ReceiptScannerService.instance;
    final image = await service.pickReceiptImage(source: source);
    
    if (image == null) return; // User canceled

    setState(() {
      _receiptImage = image;
      _isScanning = true;
    });

    try {
      final data = await service.extractReceiptData(image);
      
      if (mounted) {
        if (data != null) {
          // Harden Field Mapping: Priority mapping for AI extracted fields
          _vendorController.text = (data['merchantName'] ?? data['vendorName'] ?? data['vendor'] ?? data['merchant'] ?? '')?.toString() ?? '';
          _dateController.text = data['date']?.toString() ?? _dateController.text;
          _amountController.text = (data['totalAmount'] ?? data['amount'] ?? data['total'] ?? '')?.toString() ?? '';
          _extractedItems = data['items'] as List<dynamic>?;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI returned empty data. Please enter details manually.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        setState(() {
          _isScanning = false;
          _showForm = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _showForm = true; // Transition to form for manual entry anyway
        });
        
        // Visible Error Feedback: Inform user why AI failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Extraction Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'MANUAL', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    }
  }

  void _handleManualEntry() {
    // Clear controllers and state for clean manual entry
    _vendorController.clear();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _amountController.clear();
    _selectedCategory = null;
    
    setState(() {
      _extractedItems = [];
      _receiptImage = null;
      _showForm = true;
    });
  }

  Future<void> _pickImageForManual() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final service = ReceiptScannerService.instance;
    final image = await service.pickReceiptImage(source: source);
    if (image != null) {
      setState(() {
        _receiptImage = image;
      });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Receipt Source', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                _buildSourceOption(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery (Photo Picker)',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.accentColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      await ReceiptScannerService.instance.saveReceiptToFirebase(
        quoteId: widget.quoteId,
        vendor: _vendorController.text.trim(),
        date: _dateController.text.trim(),
        amount: amount,
        category: _selectedCategory!,
        items: _extractedItems,
        imageFile: _receiptImage,
      );

      await _saveRecentCategory(_selectedCategory!);

      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text('Save Failed'),
              ],
            ),
            content: Text(
              e.toString().contains('image_upload_failed')
                  ? 'Failed to upload receipt image. Please check your connection and try again.'
                  : e.toString().contains('permission-denied') 
                      ? 'You do not have permission to save this receipt. Please ensure you are logged in and authorized for this project.' 
                      : 'An error occurred while saving: $e'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildInitialChoice() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Receipt Scanner',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.accentColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Let AI extract your expense details automatically.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _takePhotoAndProcess,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Scan Receipt (Gemini AI)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: AppTheme.accentColor,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: AppTheme.accentColor.withAlpha(100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _handleManualEntry,
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('Enter Details Manually'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading({String title = 'Gemini is Analyzing...', String subtitle = 'Extracting items and total cost'}) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium looking loader
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                  ),
                ),
                Icon(Icons.auto_awesome, color: AppTheme.accentColor.withAlpha(150), size: 32),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    // Combine recent and default categories, removing duplicates
    final Set<String> availableCategories = {..._defaultCategories};
    
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expense Details', style: Theme.of(context).textTheme.titleLarge),
              if (_receiptImage != null)
                GestureDetector(
                  onTap: _pickImageForManual, // Allow changing the photo
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_receiptImage!, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  onPressed: _pickImageForManual,
                  tooltip: 'Attach Photo',
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vendorController,
            decoration: const InputDecoration(labelText: 'Vendor Name', border: OutlineInputBorder()),
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total Amount', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          
          if (_recentCategories.isNotEmpty) ...[
            Text('Recent', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 4),
            // Wrap widget usage: Automatically handles layout by wrapping ChoiceChips to the 
            // next line if they exceed the available horizontal space. This is essential for 
            // responsive categorization UI.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.accentColor.withAlpha(50),
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          
          Text('All Categories', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 4),
          // Wrap widget usage: Again, we use Wrap for the default categories list to ensure
          // flexible layout that adapts to any screen size without overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableCategories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppTheme.accentColor.withAlpha(50),
                onSelected: (selected) {
                  setState(() => _selectedCategory = selected ? cat : null);
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _extractedItems ??= [];
                    _extractedItems!.add({'description': '', 'quantity': 1, 'price': 0.0});
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_extractedItems != null && _extractedItems!.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: _extractedItems!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    key: ValueKey('${item['description']}_$index'),
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: item['description']?.toString() ?? '',
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Description',
                                  border: UnderlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (val) => _extractedItems![index]['description'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: item['quantity']?.toString() ?? '1',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Qty',
                                  border: UnderlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (val) => _extractedItems![index]['quantity'] = int.tryParse(val) ?? 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: item['price']?.toString() ?? '0.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Price',
                                  border: UnderlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (val) => _extractedItems![index]['price'] = double.tryParse(val) ?? 0.0,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  _extractedItems!.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10, style: BorderStyle.none),
              ),
              child: const Center(
                child: Text('No line items added yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          // Padding for keyboard
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _showForm ? _buildForm() : _buildInitialChoice(),
                if (_showForm) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _showForm = false),
                    child: const Text('Cancel & Start Over'),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
        if (_isScanning)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: _showForm 
                  ? _buildLoading(title: 'Saving Expense...', subtitle: 'Uploading receipt and data')
                  : _buildLoading(),
            ),
          ),
      ],
    );
  }
}
