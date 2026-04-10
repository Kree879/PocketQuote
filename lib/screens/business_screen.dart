import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/quote_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../services/csv_import_service.dart';
import '../models/catalog_item.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _travelRateController = TextEditingController();
  final _markupController = TextEditingController();
  
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  String _accountType = 'Cheque / Current';
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<QuoteState>();
    _companyNameController.text = state.companyName;
    _companyAddressController.text = state.companyAddress;
    _companyPhoneController.text = state.companyPhone;
    _companyEmailController.text = state.companyEmail;
    _hourlyRateController.text = state.defaultGlobalHourlyRate.toStringAsFixed(2);
    _travelRateController.text = state.defaultGlobalTravelRate.toStringAsFixed(2);
    _markupController.text = state.defaultGlobalMarkup.toStringAsFixed(2);
    
    _bankNameController.text = state.bankName;
    _accountNumberController.text = state.accountNumber;
    _branchCodeController.text = state.branchCode;
    _swiftCodeController.text = state.swiftCode;
    _accountType = state.accountType.isEmpty ? 'Cheque / Current' : state.accountType;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _hourlyRateController.dispose();
    _travelRateController.dispose();
    _markupController.dispose();
    
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    _swiftCodeController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final company = _companyNameController.text.trim();
    final address = _companyAddressController.text.trim();
    final phone = _companyPhoneController.text.trim();
    final email = _companyEmailController.text.trim();
    final rate = double.tryParse(_hourlyRateController.text) ?? 350.0;
    final travel = double.tryParse(_travelRateController.text) ?? 8.5;
    final markup = double.tryParse(_markupController.text) ?? 15.0;

    context.read<QuoteState>().updateGlobalSettings(
      companyName: company,
      companyAddress: address,
      companyPhone: phone,
      companyEmail: email,
      hourlyRate: rate,
      travelRate: travel,
      markup: markup,
      bankName: _bankNameController.text.trim(),
      accountType: _accountType,
      accountNumber: _accountNumberController.text.trim(),
      branchCode: _branchCodeController.text.trim(),
      swiftCode: _swiftCodeController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business Defaults Saved')),
    );
  }

  Future<void> _importCsv() async {
    setState(() => _isImporting = true);
    try {
      final items = await CsvImportService.pickAndParseCsv();
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import cancelled or CSV is empty')),
          );
        }
        return;
      }

      final count = await context.read<QuoteState>().importCatalogBatch(items);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D25),
            title: const Text('Import Complete', style: TextStyle(color: Colors.white)),
            content: Text('Successfully imported/updated $count items in your catalog.', 
              style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Business Defaults',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These values will be used as the starting point for all new quotes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          
          GlassContainer(
            child: Column(
              children: [
                _buildSettingField(
                  label: 'Company / Business Name',
                  controller: _companyNameController,
                  hint: 'e.g. Pocket Quote',
                  keyboardType: TextInputType.text,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Company Address',
                  controller: _companyAddressController,
                  hint: 'e.g. 123 Street, City',
                  keyboardType: TextInputType.multiline,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Contact Number',
                  controller: _companyPhoneController,
                  hint: 'e.g. +27 12 345 6789',
                  keyboardType: TextInputType.phone,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Email Address',
                  controller: _companyEmailController,
                  hint: 'e.g. hello@company.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Default Hourly Labor Rate',
                  controller: _hourlyRateController,
                  prefix: 'R',
                  hint: 'e.g. 450.00',
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Default Travel Rate (per km)',
                  controller: _travelRateController,
                  prefix: 'R',
                  hint: 'e.g. 8.50',
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Default Material Markup %',
                  controller: _markupController,
                  suffix: '%',
                  hint: 'e.g. 20.0',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'Banking & Payments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These details will automatically be appended to the bottom of all your finalized Invoices.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          
          GlassContainer(
            child: Column(
              children: [
                _buildSettingField(
                  label: 'Bank Name',
                  controller: _bankNameController,
                  hint: 'e.g. Discovery Bank',
                  keyboardType: TextInputType.text,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildDropdownField(
                  label: 'Account Type',
                  value: _accountType,
                  items: const ['Cheque / Current', 'Savings', 'Transmission'],
                  onChanged: (val) {
                    if (val != null) setState(() => _accountType = val);
                  },
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Account Number',
                  controller: _accountNumberController,
                  hint: 'e.g. 1234567890',
                  keyboardType: TextInputType.number,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Branch Code',
                  controller: _branchCodeController,
                  hint: 'e.g. 250655',
                  keyboardType: TextInputType.number,
                ),
                Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(25)),
                _buildSettingField(
                  label: 'Swift Code (Optional)',
                  controller: _swiftCodeController,
                  hint: 'e.g. ABSAZAJJ',
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('Save Business Defaults'),
          ),
          const SizedBox(height: 32),

          Text(
            'Catalog Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bulk import your standard material items and pricing using a CSV file.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import Instructions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Prepare a CSV with headers: ItemName, Price, Category\n'
                  '• Valid Categories: Electrical, Plumbing, Pool, Garden, Handyman, General\n'
                  '• Items with same name & category will update the price.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _importCsv,
                    icon: _isImporting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                    label: Text(_isImporting ? 'Parsing CSV...' : 'Select CSV to Import'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppTheme.accentColor.withAlpha(100)),
                      foregroundColor: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSettingField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    String? hint,
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: keyboardType == TextInputType.multiline ? null : 1,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
            filled: true,
            fillColor: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: isDark ? const Color(0xFF242730) : Colors.white,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
            ),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          items: items.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
