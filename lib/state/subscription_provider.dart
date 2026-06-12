import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SubscriptionProvider extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isStoreAvailable = false;
  bool _isSubscribed = false;
  bool _isLoading = false;
  int _quoteCount = 0;
  List<ProductDetails> _products = [];
  
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<User?>? _authSub;

  // Constants
  static const String _kBusinessPlanId = 'business_plan';

  SubscriptionProvider() {
    _initialize();
    _listenToAuthState();
  }

  void _listenToAuthState() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _firestoreSub?.cancel();
      if (user != null) {
        _listenToFirestore(user.uid);
      } else {
        _isSubscribed = false;
        _quoteCount = 0;
        notifyListeners();
      }
    });
  }

  void _listenToFirestore(String uid) {
    _firestoreSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        _isSubscribed = data?['isSubscribed'] ?? false;
        _quoteCount = data?['freeQuotesUsed'] ?? 0;
      } else {
        _isSubscribed = false;
        _quoteCount = 0;
      }
      notifyListeners();
    });
  }

  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  int get quoteCount => _quoteCount;
  bool get isStoreAvailable => _isStoreAvailable;
  List<ProductDetails> get products => _products;

  // The Free Tier limit is 2 generated quotes
  bool get canGenerateFreeQuote => _quoteCount < 2;

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    // Listen to purchases
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) => _listenToPurchaseUpdated(purchaseDetailsList),
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('Purchase Stream Error: $error');
      },
    );

    // Init Store Connection
    _isStoreAvailable = await _inAppPurchase.isAvailable();
    if (_isStoreAvailable) {
      // Query products
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_kBusinessPlanId});
      if (response.error == null) {
        _products = response.productDetails;
      }
      
      // Auto-restore might happen via purchaseStream or we can explicitly restore.
      await _inAppPurchase.restorePurchases();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> incrementQuoteCount() async {
    if (_isSubscribed) return; // Unnecessary to track if subscribed

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('incrementQuoteCount');
      await callable.call();
    } catch (e) {
      debugPrint('Failed to increment quote count: $e');
    }
  }

  Future<void> purchaseBusinessPlan() async {
    if (_products.isEmpty || !_isStoreAvailable) return;
    
    final product = _products.firstWhere((p) => p.id == _kBusinessPlanId);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    // Do NOT reset _isSubscribed here — _listenToPurchaseUpdated() is the sole
    // authority on subscription state. Resetting prematurely creates a race
    // condition where a subscribed user briefly appears as a free-tier user.
    notifyListeners();
    await _inAppPurchase.restorePurchases().whenComplete(() {
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
          _isLoading = false;
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          if (purchaseDetails.productID == _kBusinessPlanId) {
            _isSubscribed = false;
          }
          _isLoading = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          if (purchaseDetails.productID == _kBusinessPlanId) {
            _isLoading = true;
            notifyListeners();
            try {
              final callable = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
              await callable.call({
                'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
                'productId': purchaseDetails.productID,
                'source': purchaseDetails.verificationData.source,
              });
              // Firestore listener will update _isSubscribed automatically
            } catch (e) {
              debugPrint('Failed to verify purchase: $e');
            }
          }
          _isLoading = false;
          
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _firestoreSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
