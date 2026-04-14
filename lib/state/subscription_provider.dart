import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionProvider extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isStoreAvailable = false;
  bool _isSubscribed = false;
  bool _isLoading = false;
  int _quoteCount = 0;
  List<ProductDetails> _products = [];

  // Constants
  static const String _kGenerateQuoteCountKey = 'generated_quote_count';
  static const String _kBusinessPlanId = 'business_plan';

  SubscriptionProvider() {
    _initialize();
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

    // Load Free Tier Counter
    final prefs = await SharedPreferences.getInstance();
    _quoteCount = prefs.getInt(_kGenerateQuoteCountKey) ?? 0;

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

    final prefs = await SharedPreferences.getInstance();
    _quoteCount += 1;
    await prefs.setInt(_kGenerateQuoteCountKey, _quoteCount);
    notifyListeners();
  }

  Future<void> purchaseBusinessPlan() async {
    if (_products.isEmpty || !_isStoreAvailable) return;
    
    final product = _products.firstWhere((p) => p.id == _kBusinessPlanId);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    _isSubscribed = false; // Reset before querying the active list
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
            _isSubscribed = true;
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
    super.dispose();
  }
}
