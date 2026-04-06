import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/quote_model.dart';
import '../models/catalog_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Touch the user document to ensure it's physically created
  Future<void> touchUserDoc(String userId) async {
    try {
      await _db.collection('users').doc(userId).set({
        'last_online': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore touchUserDoc error: $e');
    }
  }

  // Sync a quote to Firestore
  Future<void> uploadQuote(String userId, QuoteModel quote) async {
    try {
      final docRef = _db.collection('users').doc(userId).collection('quotes');
      
      // Use the local UUID as the document ID for robust two-way syncing
      await docRef.doc(quote.id).set(quote.toJson());
      quote.firestoreId = quote.id; // Keep local ref in sync
    } catch (e) {
      debugPrint('Firestore upload error: $e');
      rethrow;
    }
  }

  // Get quote history for a user
  Stream<List<QuoteModel>> getQuoteHistory(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('quotes')
        .orderBy('lastModified', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['firestoreId'] = doc.id; // Ensure the doc ID is in the model
              return QuoteModel.fromJson(data);
            }).toList());
  }

  // Sync a catalog item to Firestore
  Future<void> uploadCatalogItem(String userId, CatalogItem item) async {
    try {
      final collection = _db.collection('users').doc(userId).collection('catalog');
      // Use the name as the document ID to prevent duplicates
      await collection.doc(item.name.toLowerCase().replaceAll(' ', '_')).set(item.toJson());
    } catch (e) {
      debugPrint('Firestore catalog sync error: $e');
    }
  }

  // Get user's custom catalog from Firestore
  Stream<List<CatalogItem>> getCatalog(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('catalog')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CatalogItem.fromJson(doc.data())).toList());
  }

  // Sync settings to Firestore
  Future<void> uploadSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _db.collection('users').doc(userId).collection('settings').doc('profile').set(settings, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore settings sync error: $e');
    }
  }

  // Get settings from Firestore (One-time fetch)
  Future<Map<String, dynamic>> getSettingsOnce(String userId) async {
    try {
      final snap = await _db.collection('users').doc(userId).collection('settings').doc('profile').get();
      return snap.data() ?? {};
    } catch (e) {
      debugPrint('Firestore getSettingsOnce error: $e');
      return {};
    }
  }

  // Get settings from Firestore (Stream)
  Stream<Map<String, dynamic>> getSettings(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('profile')
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }

  /// Atomic batch sync of all data categories.


  /// Uses WriteBatch to ensure efficiency and atomicity (up to 500 operations).
  Future<void> syncAllData({
    required String userId,
    required List<QuoteModel> quotes,
    required List<CatalogItem> catalog,
    required Map<String, dynamic> settings,
  }) async {
    try {
      // 1. Ensure user doc exists
      await touchUserDoc(userId);

      // Create a batch
      WriteBatch batch = _db.batch();
      int operationCount = 0;

      // 2. Add Quotes to batch
      final quotesRef = _db.collection('users').doc(userId).collection('quotes');
      for (var quote in quotes) {
        if (operationCount >= 490) { // Leave room for other ops
          await batch.commit();
          batch = _db.batch();
          operationCount = 0;
        }
        batch.set(quotesRef.doc(quote.id), quote.toJson());
        operationCount++;
      }

      // 3. Add Catalog to batch
      final catalogRef = _db.collection('users').doc(userId).collection('catalog');
      for (var item in catalog) {
        if (operationCount >= 490) {
          await batch.commit();
          batch = _db.batch();
          operationCount = 0;
        }
        final docId = item.name.toLowerCase().replaceAll(' ', '_');
        batch.set(catalogRef.doc(docId), item.toJson());
        operationCount++;
      }

      // 4. Add Settings to batch
      final settingsRef = _db.collection('users').doc(userId).collection('settings').doc('profile');
      batch.set(settingsRef, settings, SetOptions(merge: true));
      
      // Final commit
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore syncAllData error: $e');
      rethrow;
    }
  }

  // Keep for individual/legacy calls or specific error recovery
  Future<Map<String, dynamic>> forceSyncQuotes(String userId, List<QuoteModel> quotes) async {
    return {'success': 0, 'failed': 0};
  }

  // Delete a quote from Firestore
  Future<void> deleteQuote(String userId, String firestoreId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('quotes')
          .doc(firestoreId)
          .delete();
    } catch (e) {
      debugPrint('Firestore delete error: $e');
      rethrow;
    }
  }
}
