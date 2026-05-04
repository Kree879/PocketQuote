import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/receipt_scanner_service.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';

enum ScannerState { initial, loading, form }

class ReceiptScannerSheet extends StatefulWidget {
  final String quoteId;

  const ReceiptScannerSheet({super.key, required this.quoteId});

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  ScannerState _currentState = ScannerState.initial;
  
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedCategory;
  File? _receiptImage;
  
  final List<String> _defaultCategories = [
    'Materials', 'Labor', 'Fuel', 'Tools', 'Subcontractor', 'Other'
  ];
  List<String> _recentCategories = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadRecentCategories();
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

  Future<void> _handleScanReceipt() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final service = ReceiptScannerService.instance;
    final image = await service.pickReceiptImage(source: source);
    
    if (image == null) return; // User canceled

    setState(() {
      _receiptImage = image;
      _currentState = ScannerState.loading;
    });

    Map<String, dynamic>? data;
    try {
      data = await service.extractReceiptData(image);
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentState = ScannerState.form;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI took too long to respond. Please enter details manually.')),
        );
      }
      return;
    }
    
    if (mounted) {
      if (data != null) {
        _vendorController.text = data['vendor']?.toString() ?? '';
        _dateController.text = data['date']?.toString() ?? _dateController.text;
        _amountController.text = data['amount']?.toString() ?? '';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to extract data. Please enter manually.')),
        );
      }
      setState(() {
        _currentState = ScannerState.form;
      });
    }
  }

  void _handleManualEntry() {
    setState(() {
      _currentState = ScannerState.form;
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
      _currentState = ScannerState.loading;
    });

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      await ReceiptScannerService.instance.saveReceiptToFirebase(
        quoteId: widget.quoteId,
        vendor: _vendorController.text.trim(),
        date: _dateController.text.trim(),
        amount: amount,
        category: _selectedCategory!,
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
          _currentState = ScannerState.form;
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
          'Add Expense / Receipt',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _handleScanReceipt,
          icon: const Icon(Icons.document_scanner),
          label: const Text('Scan Receipt (AI)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.accentColor,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _handleManualEntry,
          icon: const Icon(Icons.edit),
          label: const Text('Enter Manually'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing... Please wait.'),
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
                const Icon(Icons.image, color: Colors.green)
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
    return Padding(
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
          child: () {
            switch (_currentState) {
              case ScannerState.initial:
                return _buildInitialChoice();
              case ScannerState.loading:
                return _buildLoading();
              case ScannerState.form:
                return _buildForm();
            }
          }(),
        ),
      ),
    );
  }
}
