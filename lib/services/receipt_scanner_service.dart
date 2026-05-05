import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_keys.dart';

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
    final apiKey = _geminiApiKey ?? ApiKeys.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API Key is not set.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    // AI Prompting: We instruct the model to specifically look for three distinct fields.
    // Specifying the exact return format (ONLY a valid JSON object) ensures that the output
    // can be reliably parsed using jsonDecode without string manipulation errors.
    // AI Prompting: Analyze receipt and return structured JSON with items array.
    final prompt = TextPart("Analyze this receipt and return a JSON object with the keys: 'merchantName', 'date', 'totalAmount', and 'items'. The 'items' key must be an array of objects, each with 'description', 'quantity', and 'price'.");
    final imageBytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);

    int retryCount = 0;
    const int maxRetries = 1; // Try once, then retry once more

    while (true) {
      try {
        final response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]).timeout(const Duration(seconds: 30));

        if (response.text != null) {
          // AI Debugging: Log success and raw response to troubleshoot parsing issues
          debugPrint('Gemini Response: 200 OK');
          debugPrint('Gemini Raw Response: ${response.text}');

          String jsonText = response.text!.trim();
          
          // Harden JSON Parsing: Remove Markdown formatting if present
          jsonText = jsonText
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          
          try {
            final data = jsonDecode(jsonText) as Map<String, dynamic>;
            debugPrint('Gemini Parsed Data: $data');
            return data;
          } catch (e) {
            debugPrint('JSON Parsing Error: $e. Content: $jsonText');
            throw Exception('Failed to parse AI response. The receipt might be too complex or blurry.');
          }
        }
        break; // Exit loop if text is null (shouldn't happen with success)
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Check for 503 (Service Unavailable) or "overloaded" which are typical for busy servers
        if ((errorStr.contains('503') || errorStr.contains('service unavailable') || errorStr.contains('overloaded')) && retryCount < maxRetries) {
          retryCount++;
          debugPrint('Gemini Service Busy (503). Retry attempt $retryCount of $maxRetries in 1 second...');
          await Future.delayed(const Duration(seconds: 1));
          continue; // Retry the loop
        }
        
        debugPrint('Error extracting receipt data: $e');
        rethrow;
      }
    }
    return null;
  }

  Future<void> saveReceiptToFirebase({
    required String quoteId,
    required String vendor,
    required String date,
    required double amount,
    required String category,
    List<dynamic>? items,
    File? imageFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }
    final userId = user.uid;
    debugPrint('ReceiptScannerService: saveReceiptToFirebase for userId: $userId to Firestore and Storage path: users/$userId/quotes/$quoteId/receipts');

    String? imageUrl;
    
    if (imageFile != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
      final uploadPath = 'users/$userId/quotes/$quoteId/receipts/$fileName';
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
      'vendorName': vendor, // Maps to 'merchantName' from Gemini in UI
      'date': Timestamp.fromDate(parsedDate),
      'totalAmount': amount,
      'category': category,
      'items': items ?? [],
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('quotes')
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
