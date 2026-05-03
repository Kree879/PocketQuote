import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<File?> pickReceiptImage({ImageSource source = ImageSource.camera}) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80, // slight compression
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
      ]);

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
      return null;
    }
    return null;
  }

  Future<void> saveReceiptToFirebase({
    required String projectId,
    required String vendor,
    required String date,
    required double amount,
    required String category,
    File? imageFile,
  }) async {
    String? imageUrl;
    
    if (imageFile != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('projects')
          .child(projectId)
          .child('receipts')
          .child(fileName);
      
      final uploadTask = await ref.putFile(imageFile);
      imageUrl = await uploadTask.ref.getDownloadURL();
    }

    final receiptData = {
      'vendor': vendor,
      'date': date,
      'amount': amount,
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('receipts')
        .add(receiptData);
  }
}
