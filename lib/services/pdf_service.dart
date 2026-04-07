import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/quote_model.dart';
import '../state/quote_state.dart';
import 'google_drive_auth_service.dart';
import 'firestore_service.dart';

class PdfService {
  /// Helper to save data to a temporary file before pushing to Drive
  static Future<File> _saveToTempFile(Uint8List data, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(data);
    return file;
  }

  /// Generates a PDF and saves it to the user's Google Drive backup folder.
  static Future<void> saveQuotePdfToDrive({
    required BuildContext context,
    required QuoteModel quote,
    required QuoteState globalState,
    bool isInvoice = false,
  }) async {
    final driveService = GoogleDriveAuthService.instance;
    final firestore = FirestoreService();
    
    if (!driveService.isAuthorized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive not connected. Please link it in settings.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      // 1. Fetch latest profile settings to get the 350 hourly / 15% markup
      final profile = await firestore.getSettingsOnce(globalState.currentUser?.uid ?? '');
      
      // 2. Generate PDF using profile values (default to 350/15 as requested)
      final bytes = await generateQuotePDF(
        quote: quote,
        globalState: globalState,
        isInvoice: isInvoice,
        overrideHourlyRate: (profile['hourlyRate'] ?? 350).toDouble(),
        overrideMarkup: (profile['markupPercentage'] ?? 15).toDouble(),
      );

      // 3. Prepare filename: PocketQuote_Quote_[ClientName]_[Date].pdf
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final prefix = isInvoice ? "PocketQuote_Invoice" : "PocketQuote_Quote";
      final clientSafe = (quote.clientName.isEmpty ? "Client" : quote.clientName)
          .trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').replaceAll(' ', '_');
      final fileName = "${prefix}_${clientSafe}_$dateStr.pdf";
 
      // 4. Save to temporary local storage for a split second
      final tempFile = await _saveToTempFile(bytes, fileName);
      final fileBytes = await tempFile.readAsBytes();
 
      // 5. Upload to Drive natively without hardcoded folderId
      final fileId = await driveService.uploadFile(
        data: fileBytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
 
      if (context.mounted) {
 
        if (fileId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pocket Quote PDF successfully uploaded to Drive!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload Pocket Quote PDF to Drive.'), backgroundColor: Colors.redAccent),
          );
        }
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Upload error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  static Future<void> generateAndSharePDF({
    required BuildContext context,
    required QuoteModel quote,
    required QuoteState globalState,
    bool isInvoice = false,
  }) async {
    final bytes = await generateQuotePDF(
      quote: quote,
      globalState: globalState,
      isInvoice: isInvoice,
    );
    
    final projectName = quote.projectTitle.isNotEmpty ? quote.projectTitle : "Project";
    final prefix = isInvoice ? "Invoice" : "Quote";
    final safeProjectName = projectName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').replaceAll(' ', '_');
    final fileName = "${prefix}_$safeProjectName.pdf";
    final subject = "${globalState.companyName.isNotEmpty ? globalState.companyName : 'Pocket Quote'} - $projectName";
    
    final double baseMaterialsCost = quote.materials.fold(0.0, (sum, item) => sum + item.totalCost);
    final double materialsMarkupCost = baseMaterialsCost * (quote.markupPercentage / 100);
    final double laborCost = quote.hourlyRate * quote.estimatedHours;
    final double travelCost = quote.useFlatTravelFee ? quote.flatTravelFee : (quote.travelCostPerKm * quote.travelDistanceKm);
    final double callOutCost = quote.useCallOutFee ? quote.callOutFeeAmount : 0.0;
    final double computedTotal = callOutCost + laborCost + travelCost + baseMaterialsCost + materialsMarkupCost;

    final text = "Hi ${quote.clientName.isEmpty ? 'Customer' : quote.clientName},\n\n"
                 "Please find the attached ${isInvoice ? 'invoice' : 'quote'} for $projectName.\n"
                 "Total Amount: R${computedTotal.toStringAsFixed(2)}\n\n"
                 "Best regards,\n"
                 "${globalState.companyName.isNotEmpty ? globalState.companyName : 'Pocket Quote Contractor'}";

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
      subject: subject,
      text: text,
    );
    
    // Auto-backup to Drive without blocking UI flow
    saveQuotePdfToDrive(
      context: context, 
      quote: quote, 
      globalState: globalState, 
      isInvoice: isInvoice
    ).catchError((e) {
      debugPrint("Auto-backup failed: $e");
    });
  }


  static Future<Uint8List> generateQuotePDF({
    required QuoteModel quote,
    required QuoteState globalState,
    bool isInvoice = false,
    double? overrideHourlyRate,
    double? overrideMarkup,
  }) async {
    final pdf = pw.Document();

    // Use overrides if provided (for Drive backup logic)
    final hRate = overrideHourlyRate ?? quote.hourlyRate;
    final mPercentage = overrideMarkup ?? quote.markupPercentage;

    // Calculations
    final double baseMaterialsCost = quote.materials.fold(0.0, (sum, item) => sum + item.totalCost);
    final double materialsMarkupCost = baseMaterialsCost * (mPercentage / 100);
    final double laborCost = hRate * quote.estimatedHours;
    final double travelCost = quote.useFlatTravelFee ? quote.flatTravelFee : (quote.travelCostPerKm * quote.travelDistanceKm);
    final double callOutCost = quote.useCallOutFee ? quote.callOutFeeAmount : 0.0;
    
    double computedTotal = callOutCost + laborCost + travelCost + baseMaterialsCost + materialsMarkupCost;
    if (computedTotal < 0) computedTotal = 0;
    
    final headerTitle = isInvoice ? 'INVOICE' : 'QUOTE';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(headerTitle, 
                        style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Quote ID: ${quote.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(globalState.companyName.isNotEmpty ? globalState.companyName.toUpperCase() : 'POCKET QUOTE', 
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (globalState.companyAddress.isNotEmpty)
                      pw.Text(globalState.companyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700), textAlign: pw.TextAlign.right),
                    if (globalState.companyPhone.isNotEmpty)
                      pw.Text('Tel: ${globalState.companyPhone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (globalState.companyEmail.isNotEmpty)
                      pw.Text(globalState.companyEmail, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 2, color: PdfColors.blue900, height: 32),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Client:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text(quote.clientName.isEmpty ? "Valued Client" : quote.clientName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                if (quote.projectTitle.isNotEmpty)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Project:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(quote.projectTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Materials Table
            pw.Text('Materials & Parts', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Unit (R)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total (R)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...quote.materials.map((m) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(m.name)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${m.quantity}', textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(m.cost.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(m.totalCost.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                  ],
                )),
                if (quote.materials.isEmpty) pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No materials added', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))),
                    pw.Text(''), pw.Text(''), pw.Text(''),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Summary Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      _buildPdfRow('Materials Base:', baseMaterialsCost),
                      _buildPdfRow('Materials Markup ($mPercentage%):', materialsMarkupCost),
                      _buildPdfRow('Labor Cost:', laborCost),
                      _buildPdfRow('Travel Cost:', travelCost),
                      if (quote.useCallOutFee) _buildPdfRow('Call-Out Fee:', callOutCost),
                      pw.Divider(thickness: 1, color: PdfColors.grey400),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Text('R${computedTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (quote.photoPaths.isNotEmpty) {
      final List<pw.MemoryImage> images = [];
      for (final path in quote.photoPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            images.add(pw.MemoryImage(bytes));
          }
        } catch (e) {
          debugPrint('Error reading photo for PDF: $e');
        }
      }

      if (images.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) => [
              pw.Header(level: 0, child: pw.Text('PROJECT PHOTOS', style: pw.TextStyle(fontSize: 18, color: PdfColors.blue900))),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 12,
                runSpacing: 12,
                children: images.map((img) => pw.Container(
                  width: 240,
                  height: 240,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Image(img, fit: pw.BoxFit.cover),
                )).toList(),
              ),
            ],
          ),
        );
      }
    }

    return await pdf.save();
  }

  static pw.Widget _buildPdfRow(String label, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text('R${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
