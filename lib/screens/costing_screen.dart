import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../state/quote_state.dart';
import '../widgets/glass_container.dart';
import '../models/material_item.dart';
import '../models/trade_category.dart';
import 'quote_summary_screen.dart';

class CostingScreen extends StatefulWidget {
  const CostingScreen({super.key});

  @override
  State<CostingScreen> createState() => _CostingScreenState();
}

class _CostingScreenState extends State<CostingScreen> {
  final _laborRateController = TextEditingController();
  final _laborHoursController = TextEditingController();
  final _travelDistanceController = TextEditingController();
  final _travelRateController = TextEditingController();
  final _markupController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _projectTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<QuoteState>();
      _clientNameController.text = state.clientName;
      _projectTitleController.text = state.projectTitle;
      _laborRateController.text = state.hourlyRate > 0 ? state.hourlyRate.toStringAsFixed(2) : '';
      _laborHoursController.text = state.estimatedHours > 0 ? state.estimatedHours.toStringAsFixed(2) : '';
      _travelDistanceController.text = state.travelDistanceKm > 0 ? state.travelDistanceKm.toStringAsFixed(2) : '';
      _travelRateController.text = state.travelCostPerKm > 0 ? state.travelCostPerKm.toStringAsFixed(2) : '';
      _markupController.text = state.markupPercentage > 0 ? state.markupPercentage.toStringAsFixed(2) : '';
    });
  }

  @override
  void dispose() {
    _laborRateController.dispose();
    _laborHoursController.dispose();
    _travelDistanceController.dispose();
    _travelRateController.dispose();
    _markupController.dispose();
    _clientNameController.dispose();
    _projectTitleController.dispose();
    super.dispose();
  }

  void _onLaborChanged() {
    final rate = double.tryParse(_laborRateController.text) ?? 0.0;
    final hours = double.tryParse(_laborHoursController.text) ?? 0.0;
    context.read<QuoteState>().updateLabor(rate, hours);
  }

  void _onTravelChanged() {
    final dist = double.tryParse(_travelDistanceController.text) ?? 0.0;
    final rate = double.tryParse(_travelRateController.text) ?? 0.0;
    context.read<QuoteState>().updateTravelDistanceBased(rate, dist);
  }

  void _onMarkupChanged() {
    final markup = double.tryParse(_markupController.text) ?? 0.0;
    context.read<QuoteState>().updateMarkup(markup);
  }

  void _showAddMaterialBottomSheet() {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final catInfo = TradeCategoryInfo.fromCategory(context.read<QuoteState>().selectedCategory);
    final quoteState = context.read<QuoteState>();
    final userCatalog = quoteState.userCatalog
        .where((item) => item.category == quoteState.selectedCategory)
        .map((item) => CommonMaterial(item.name, item.defaultCost))
        .toList();
    final allSuggestions = [...catInfo.quickMaterials, ...userCatalog];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 48, // Lifted up more from the bottom
          ),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add ${catInfo.materialLabel.split(' / ')[0]}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: catInfo.glowColor)),
                const SizedBox(height: 16),
                
                // Replacement for Chips: Searchable Dropdown (Autocomplete)
                Autocomplete<CommonMaterial>(
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return allSuggestions;
                    }
                    return allSuggestions.where((option) =>
                        option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (CommonMaterial selection) {
                    nameController.text = selection.name;
                    costController.text = selection.cost.toStringAsFixed(2);
                  },
                  fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                    // Sync the external nameController with the internal fieldController
                    fieldController.text = nameController.text;
                    fieldController.addListener(() {
                      nameController.text = fieldController.text;
                    });

                    return TextField(
                      controller: fieldController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'Search or add new...',
                        suffixIcon: Icon(Icons.search, color: catInfo.glowColor.withAlpha(150)),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          height: 200,
                          width: MediaQuery.of(context).size.width - 48,
                          child: GlassContainer(
                            borderRadius: 16,
                            padding: EdgeInsets.zero,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final CommonMaterial option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option.name),
                                  subtitle: Text('Default: ${context.read<QuoteState>().currencySymbol}${option.cost.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall),
                                  trailing: Icon(Icons.add_circle_outline, color: catInfo.glowColor, size: 18),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 1. Cost Field (Smaller)
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Cost', prefixText: quoteState.currencySymbol),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. Qty Field (Middle)
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. Quick Save to Catalog Button
                    Container(
                      height: 56, // Match standard field height
                      width: 56,
                      decoration: BoxDecoration(
                        color: catInfo.glowColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: catInfo.glowColor.withAlpha(80)),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: catInfo.glowColor),
                        tooltip: 'Save to Catalog',
                        onPressed: () {
                          if (nameController.text.isNotEmpty && costController.text.isNotEmpty) {
                            final cost = double.tryParse(costController.text) ?? 0.0;
                            context.read<QuoteState>().saveToCatalog(
                              nameController.text, 
                              cost, 
                              context.read<QuoteState>().selectedCategory
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${nameController.text}" saved to catalog'),
                                backgroundColor: catInfo.glowColor.withAlpha(200),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty && costController.text.isNotEmpty) {
                      final cost = double.tryParse(costController.text) ?? 0.0;
                      final qty = int.tryParse(qtyController.text) ?? 1;
                      
                      context.read<QuoteState>().addMaterial(
                        MaterialItem(name: nameController.text, cost: cost, quantity: qty)
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: catInfo.glowColor,
                  ),
                  child: const Text('Add to Quote'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Image Source', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      context.read<QuoteState>().pickImage(ImageSource.camera);
                    },
                  ),
                  _SourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      context.read<QuoteState>().pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showFullScreenPreview(BuildContext context, List<String> paths, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoViewGallery.builder(
            itemCount: paths.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(paths[index])),
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: paths[index]),
              );
            },
            pageController: PageController(initialPage: initialIndex),
            scrollPhysics: const BouncingScrollPhysics(),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Costing Engine'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft Saved')));
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: Icon(Icons.bookmark, color: Theme.of(context).appBarTheme.iconTheme?.color),
            label: Text('Save for Later', style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 14)),
          ),
        ],
      ),
      body: Consumer<QuoteState>(
        builder: (context, state, child) {
          final categoryInfo = TradeCategoryInfo.fromCategory(state.selectedCategory);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Client & Project Info
                    Text('Job Identification', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Column(
                        children: [
                          TextField(
                            controller: _projectTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Job / Project Title',
                              hintText: 'e.g. Garden Overhaul',
                            ),
                            onChanged: (val) => context.read<QuoteState>().updateProjectTitle(val),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _clientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Client Name',
                              hintText: 'Enter client name',
                            ),
                            onChanged: (val) => context.read<QuoteState>().updateClientName(val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Photo Tray Section
                    Text('Photos / Attachments', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Add Photo Card
                          GestureDetector(
                            onTap: () => _showImageSourcePicker(context),
                            child: GlassContainer(
                              width: 100,
                              padding: EdgeInsets.zero,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: categoryInfo.glowColor, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('Add Photo', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Thumbnails
                          ...state.photoPaths.asMap().entries.map((entry) {
                            final int index = entry.key;
                            final String photoPath = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showFullScreenPreview(context, state.photoPaths, index),
                                    child: GlassContainer(
                                      width: 100,
                                      padding: EdgeInsets.zero,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.file(
                                          File(photoPath),
                                          width: 100,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => state.removePhoto(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Call-Out Fee Section
                    Text('Call-Out Fee', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Standard Call-Out Fee (${state.currencySymbol}${state.callOutFeeAmount.toStringAsFixed(2)})',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          Switch(
                            value: state.useCallOutFee,
                            activeThumbColor: categoryInfo.glowColor,
                            onChanged: (val) {
                              context.read<QuoteState>().updateCallOutFee(val, state.callOutFeeAmount);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Labor Section
                    Text('Labor', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _laborRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Hourly Rate', prefixText: state.currencySymbol),
                              onChanged: (_) => _onLaborChanged(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _laborHoursController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Est. Hours'),
                              onChanged: (_) => _onLaborChanged(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Travel Section
                    Text('Travel', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _travelDistanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Distance', suffixText: 'km'),
                              onChanged: (_) => _onTravelChanged(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _travelRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Rate/km', prefixText: state.currencySymbol),
                              onChanged: (_) => _onTravelChanged(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Materials Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(categoryInfo.materialLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: categoryInfo.glowColor, size: 28),
                          onPressed: _showAddMaterialBottomSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (state.materials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No materials added. ${categoryInfo.materialHint}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ...state.materials.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text('${item.quantity}x @ ${state.currencySymbol}${item.cost.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            Text('${state.currencySymbol}${item.totalCost.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => state.removeMaterial(item.id),
                            )
                          ],
                        ),
                      ),
                    )),
                    
                    const SizedBox(height: 24),

                    // Markup Section
                    Text('Material Markup', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: categoryInfo.glowColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Add profit margin to materials cost',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _markupController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Markup', suffixText: '%'),
                              onChanged: (_) => _onMarkupChanged(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 120), // Padding for sticky footer
                  ],
                ),
              ),

              // Sticky Footer
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(76), // 0.3 * 255
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Cost', style: Theme.of(context).textTheme.bodyLarge),
                          Text(
                            '${state.currencySymbol}${state.totalCost.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: categoryInfo.glowColor,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QuoteSummaryScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: categoryInfo.glowColor,
                        ),
                        child: const Text('Review Quote'),
                      ),
                    ],
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

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
