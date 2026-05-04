import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScannerService {
  static final ReceiptScannerService instance = ReceiptScannerService._internal();

  ReceiptScannerService._internal();

  final _imagePicker = ImagePicker();
  
  // Note: For a production app, the API key should be fetched securely from a backend.
  // We'll use a placeholder or expect it to be passed in. 
  // For now, let's allow setting the API key or pulling it from env.
  String? _geminiApiKey;

  void init(String apiKey) {
    _geminiApiKey = apiKey;
  }

  Future<File?> pickReceiptImage({required ImageSource source}) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85, // compression with max width
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<Map<String, dynamic>?> extractReceiptData(File imageFile) async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      throw Exception('Gemini API Key is not set.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey!,
    );

    // AI Prompting: We instruct the model to specifically look for three distinct fields.
    // Specifying the exact return format (ONLY a valid JSON object) ensures that the output
    // can be reliably parsed using jsonDecode without string manipulation errors.
    final prompt = TextPart('Extract the Vendor Name, Date (formatted as YYYY-MM-DD), and Total Amount (as a raw number without currency symbols) from this receipt. Return ONLY a valid JSON object with keys "vendor", "date", and "amount".');
    final imageBytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]).timeout(const Duration(seconds: 30));

      if (response.text != null) {
        String jsonText = response.text!.trim();
        // Sometimes the model wraps in ```json ... ```
        if (jsonText.startsWith('```json')) {
          jsonText = jsonText.replaceAll('```json', '');
        }
        if (jsonText.startsWith('```')) {
           jsonText = jsonText.replaceAll('```', '');
        }
        jsonText = jsonText.trim();
        
        final data = jsonDecode(jsonText) as Map<String, dynamic>;
        return data;
      }
    } catch (e) {
      print('Error extracting receipt data: $e');
      rethrow;
    }
    return null;
  }

  Future<void> saveReceiptToFirebase({
    required String quoteId,
    required String vendor,
    required String date,
    required double amount,
    required String category,
    File? imageFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }
    final userId = user.uid;
    debugPrint('ReceiptScannerService: saveReceiptToFirebase for userId: $userId to path: users/$userId/projects/$quoteId/receipts');

    String? imageUrl;
    
    if (imageFile != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
      final uploadPath = 'users/$userId/projects/$quoteId/receipts/$fileName';
      debugPrint('ReceiptScannerService: Starting upload to path: $uploadPath');
      
      final ref = FirebaseStorage.instance.ref().child(uploadPath);
      
      try {
        final snapshot = await ref.putFile(imageFile);
        if (snapshot.state == TaskState.success) {
          imageUrl = await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('image_upload_failed');
        }
      } on FirebaseException catch (e) {
        debugPrint('Firebase Storage Error [${e.code}]: ${e.message}');
        rethrow; // Rethrow to allow UI to handle specific codes like 'permission-denied'
      } catch (e) {
        debugPrint('General storage error: $e');
        throw Exception('image_upload_failed');
      }
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final receiptData = {
      'vendorName': vendor,
      'date': Timestamp.fromDate(parsedDate),
      'totalAmount': amount,
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(quoteId)
          .collection('receipts')
          .add(receiptData);
    } on FirebaseException catch (e) {
      debugPrint('Firebase Firestore Error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Firebase save error: $e');
      rethrow;
    }
  }
}
