import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/catalog_item.dart';
import '../models/trade_category.dart';

class CsvImportService {
  /// Result class to hold import details
  static Future<List<CatalogItem>> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return [];
      }

      final file = File(result.files.single.path!);
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      if (fields.isEmpty) return [];

      // Find indices of headers
      final headers = fields[0].map((e) => e.toString().trim().toLowerCase()).toList();
      int? nameIdx = _findHeaderIndex(headers, 'itemname');
      int? priceIdx = _findHeaderIndex(headers, 'price');
      int? categoryIdx = _findHeaderIndex(headers, 'category');

      if (nameIdx == -1 || priceIdx == -1 || categoryIdx == -1) {
        // Fallback or throw error? For now return empty or specialized report.
        throw Exception("Invalid CSV format. Missing one of: ItemName, Price, Category");
      }

      final List<CatalogItem> items = [];

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length <= _max(nameIdx, priceIdx, categoryIdx)) continue;

        final name = row[nameIdx].toString().trim();
        final priceStr = row[priceIdx].toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final price = double.tryParse(priceStr);
        final categoryStr = row[categoryIdx].toString().trim();
        final category = _mapCategory(categoryStr);

        if (name.isNotEmpty && price != null && category != null) {
          items.add(CatalogItem(
            name: name,
            defaultCost: price,
            category: category,
          ));
        }
      }

      return items;
    } catch (e) {
      rethrow;
    }
  }

  static int _findHeaderIndex(List<String> headers, String target) {
    return headers.indexOf(target);
  }

  static int _max(int a, int b, int c) {
    if (a > b && a > c) return a;
    if (b > c) return b;
    return c;
  }

  static TradeCategory? _mapCategory(String value) {
    final v = value.toLowerCase();
    if (v.contains('elect')) return TradeCategory.electrical;
    if (v.contains('plumb')) return TradeCategory.plumbing;
    if (v.contains('pool')) return TradeCategory.pool;
    if (v.contains('garden') || v.contains('landscap')) return TradeCategory.garden;
    if (v.contains('handy')) return TradeCategory.handyman;
    if (v.contains('general') || v.contains('custom')) return TradeCategory.general;
    return null;
  }
}
