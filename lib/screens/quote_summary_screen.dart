import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/quote_state.dart';
import '../models/trade_category.dart';
import '../widgets/glass_container.dart';
import '../services/pdf_service.dart';
import '../models/quote_model.dart';

class QuoteSummaryScreen extends StatelessWidget {
  const QuoteSummaryScreen({super.key});

  Future<void> _generateAndSharePDF(BuildContext context, QuoteState state) async {
    final quoteModel = QuoteModel(
      id: state.currentQuoteId ?? '',
      clientName: state.clientName,
      status: state.currentStatus,
      lastModified: DateTime.now(),
      category: state.selectedCategory,
      useCallOutFee: state.useCallOutFee,
      callOutFeeAmount: state.callOutFeeAmount,
      hourlyRate: state.hourlyRate,
      estimatedHours: state.estimatedHours,
      travelCostPerKm: state.travelCostPerKm,
      travelDistanceKm: state.travelDistanceKm,
      flatTravelFee: state.flatTravelFee,
      useFlatTravelFee: state.useFlatTravelFee,
      materials: state.materials,
      markupPercentage: state.markupPercentage,
      totalCostCached: state.totalCost,
      photoPaths: state.photoPaths,
      projectTitle: state.projectTitle,
    );

    await PdfService.generateAndSharePDF(
      context: context,
      quote: quoteModel,
      globalState: state,
    );

    await state.markAsSent();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote sent successfully!')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Summary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<QuoteState>(
        builder: (context, state, child) {
          final catInfo = TradeCategoryInfo.fromCategory(state.selectedCategory);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Final Estimate', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                      Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(50)),
                      if (state.useCallOutFee) ...[
                        _SummaryRow(title: 'Call-Out Fee', amount: state.callOutFeeAmount, context: context),
                        const SizedBox(height: 12),
                      ],
                      _SummaryRow(title: 'Labor', amount: state.laborCost, context: context),
                      const SizedBox(height: 12),
                      _SummaryRow(title: 'Travel', amount: state.travelCost, context: context),
                      const SizedBox(height: 12),
                      _SummaryRow(title: 'Materials (Base)', amount: state.baseMaterialsCost, context: context),
                      if (state.markupPercentage > 0) ...[
                        const SizedBox(height: 12),
                        _SummaryRow(title: 'Material Markup (${state.markupPercentage}%)', amount: state.materialsMarkupCost, context: context),
                      ],
                      Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(50)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL DUE', style: Theme.of(context).textTheme.titleMedium),
                          Text('R${state.totalCost.toStringAsFixed(2)}', 
                               style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: catInfo.glowColor,
                               )),
                        ],
                      ),
                      if (state.photoPaths.isNotEmpty) ...[
                        Divider(height: 32, color: Theme.of(context).dividerColor.withAlpha(50)),
                        Text('Photo Attachments', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: state.photoPaths.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(state.photoPaths[index]),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _generateAndSharePDF(context, state),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF & Share'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: catInfo.glowColor,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.isDriveLinked)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final quote = QuoteModel(
                        id: state.currentQuoteId ?? '',
                        clientName: state.clientName,
                        status: state.currentStatus,
                        lastModified: DateTime.now(),
                        category: state.selectedCategory,
                        useCallOutFee: state.useCallOutFee,
                        callOutFeeAmount: state.callOutFeeAmount,
                        hourlyRate: state.hourlyRate,
                        estimatedHours: state.estimatedHours,
                        travelCostPerKm: state.travelCostPerKm,
                        travelDistanceKm: state.travelDistanceKm,
                        flatTravelFee: state.flatTravelFee,
                        useFlatTravelFee: state.useFlatTravelFee,
                        materials: state.materials,
                        markupPercentage: state.markupPercentage,
                        totalCostCached: state.totalCost,
                        photoPaths: state.photoPaths,
                        projectTitle: state.projectTitle,
                      );
                      await PdfService.saveQuotePdfToDrive(
                        context: context,
                        quote: quote,
                        globalState: state,
                      );
                    },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save to Drive'),

                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: catInfo.glowColor.withAlpha(100)),
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
                  label: Text('Back to Dashboard', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final double amount;
  final BuildContext context;

  const _SummaryRow({required this.title, required this.amount, required this.context});

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        Text('R${amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
