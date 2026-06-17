import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScannerService {
  static final ReceiptScannerService instance = ReceiptScannerService._internal();

  ReceiptScannerService._internal();

  final _imagePicker = ImagePicker();

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
