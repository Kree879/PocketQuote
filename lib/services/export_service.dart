import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'google_drive_auth_service.dart';

class ExportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Helper to save data to a temporary file before pushing to Drive
  static Future<File> _saveToTempFile(Uint8List data, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(data);
    return file;
  }

  /// Generates the Catalog CSV as bytes.
  static Future<Uint8List> generateCatalogCsvBytes(String userId) async {
    final catalogSnap = await _db.collection('users').doc(userId).collection('catalog').get();

    final List<List<dynamic>> rows = [
      ['Item Name', 'Price (R)', 'Unit']
    ];

    for (final doc in catalogSnap.docs) {
      final d = doc.data();
      rows.add([
        d['name'] ?? '',
        (d['defaultCost'] ?? 0).toDouble(),
        d['unit'] ?? 'unit', // Ensuring we map 'unit' as requested
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  /// Generates the History CSV as bytes.
  static Future<Uint8List> generateHistoryCsvBytes(String userId) async {
    final quotesSnap = await _db
        .collection('users')
        .doc(userId)
        .collection('quotes')
        .orderBy('lastModified', descending: false)
        .get();

    final List<List<dynamic>> rows = [
      ['Client', 'Total (R)', 'Date']
    ];

    final dateFmt = DateFormat('yyyy-MM-dd');

    for (final doc in quotesSnap.docs) {
      final d = doc.data();
      
      String dateStr = '';
      final rawDate = d['lastModified'];
      if (rawDate is Timestamp) {
        dateStr = dateFmt.format(rawDate.toDate());
      } else if (rawDate is String) {
        try {
          dateStr = dateFmt.format(DateTime.parse(rawDate));
        } catch (_) {
          dateStr = rawDate;
        }
      }

      rows.add([
        d['clientName'] ?? '',
        (d['totalCostCached'] ?? 0).toDouble(),
        dateStr,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  /// Batch export both CSV files to Drive
  static Future<void> exportAllDataBatch({
    required BuildContext context,
    required String userId,
  }) async {
    final driveService = GoogleDriveAuthService.instance;
    
    if (!driveService.isAuthorized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive not connected. Please link it in settings.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 1. Export Catalog
      final catalogBytes = await generateCatalogCsvBytes(userId);
      final catalogFileName = 'Kree8_Catalog_$dateStr.csv';
      
      // Save locally for a split second
      final catalogFile = await _saveToTempFile(catalogBytes, catalogFileName);
      final catalogFileBytes = await catalogFile.readAsBytes();

      await driveService.uploadFile(
        data: catalogFileBytes,
        fileName: catalogFileName,
        mimeType: 'text/csv',
        folderId: '1eufszFfuDyDAsRiU8ECv3vxRZFwbynKK',
      );

      // 2. Export History
      final historyBytes = await generateHistoryCsvBytes(userId);
      final historyFileName = 'Kree8_Quote_History_$dateStr.csv';
      
      // Save locally
      final historyFile = await _saveToTempFile(historyBytes, historyFileName);
      final historyFileBytes = await historyFile.readAsBytes();

      await driveService.uploadFile(
        data: historyFileBytes,
        fileName: historyFileName,
        mimeType: 'text/csv',
        folderId: '1eufszFfuDyDAsRiU8ECv3vxRZFwbynKK',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kree8 Data (Catalog & History) backed up to Drive!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kree8 Export error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }

  }

  /// Keep for manual/share legacy
  static Future<void> exportAllToCSV({
    required BuildContext context,
    required String userId,
  }) async {
    // We can keep the legacy combined logic or update to share one by one.
    // For now, let's keep it simple as the user is focused on Drive.
  }
}
