import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/material_item.dart';
import '../models/trade_category.dart';
import '../models/quote_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/catalog_item.dart';
import '../services/google_drive_auth_service.dart';
import '../services/onedrive_service.dart';

class QuoteState extends ChangeNotifier {
  Timer? _debounceTimer;
  final Box<QuoteModel> _box = Hive.box<QuoteModel>('quotes');
  final Box _settingsBox = Hive.box('settings');
  final Box<CatalogItem> _catalogBox = Hive.box<CatalogItem>('custom_materials');
  final ImagePicker _picker = ImagePicker();

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleDriveAuthService _driveAuthService = GoogleDriveAuthService.instance;
  final OneDriveAuthService _oneDriveAuthService = OneDriveAuthService.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<QuoteModel>>? _cloudHistorySubscription;
  StreamSubscription<List<CatalogItem>>? _catalogSubscription;

  // Authentication State
  User? currentUser;

  // Global Store
  List<QuoteModel> savedQuotes = []; // Now represents Hive Drafts
  List<QuoteModel> cloudHistory = []; // Represents Firestore Sent/Completed
  List<CatalogItem> userCatalog = [];

  // Google Drive State
  bool get isDriveLinked => _driveAuthService.isSignedIn;
  bool get isDriveAuthorized => _driveAuthService.isAuthorized;
  String? get driveUserEmail => _driveAuthService.currentUser?.email;

  // OneDrive State
  bool get isOneDriveLinked => _oneDriveAuthService.isSignedIn;

  List<QuoteModel> get jobHistory {
    final currentUserId = currentUser?.uid;
    final localJobs = _box.values.where((q) => q.status != QuoteStatus.draft && q.userId == currentUserId).toList();
    final Map<String, QuoteModel> merged = {};
    for (var q in localJobs) {
      merged[q.id] = q;
    }
    for (var q in cloudHistory) {
      if (merged.containsKey(q.id)) {
        if (q.lastModified.isAfter(merged[q.id]!.lastModified)) {
          merged[q.id] = q;
        }
      } else {
        merged[q.id] = q;
      }
    }
    return merged.values.toList()..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

  // Current Session Identifiers
  String? currentQuoteId;
  String clientName = '';
  String projectTitle = '';
  QuoteStatus currentStatus = QuoteStatus.draft;

  // Category & Call-Out Fee
  TradeCategory selectedCategory = TradeCategory.general;
  bool useCallOutFee = false;
  double callOutFeeAmount = 50.0;

  // Labor
  double hourlyRate = 0.0;
  double estimatedHours = 0.0;

  // Travel
  double travelCostPerKm = 0.0;
  double travelDistanceKm = 0.0;
  double flatTravelFee = 0.0;
  bool useFlatTravelFee = false;

  // Materials
  List<MaterialItem> materials = [];
  
  // Markup
  double markupPercentage = 0.0;

  // Photos
  List<String> photoPaths = [];

  // Global Business Overrides
  String companyName = '';
  String companyAddress = '';
  String companyPhone = '';
  String companyEmail = '';
  double defaultGlobalHourlyRate = 350.0;
  double defaultGlobalTravelRate = 8.5;
  double defaultGlobalMarkup = 15.0;

  // Banking Details
  String bankName = '';
  String accountType = '';
  String accountNumber = '';
  String branchCode = '';
  String swiftCode = '';

  // App Theme Mode
  bool isDarkMode = true;

  // Sync Status
  bool isSyncing = false;
  DateTime? lastSyncedAt;

  QuoteState() {
    _loadSettings();
    loadLocalDrafts();
    _loadLocalCatalog();
    _listenToAuth();
    _initDriveService();
  }

  Future<void> _initDriveService() async {
    await _driveAuthService.initialize();
    _oneDriveAuthService.initialize();
    notifyListeners();
  }

  void _listenToAuth() {
    _authSubscription = _authService.user.listen((user) {
      currentUser = user;
      if (user != null) {
        _firestoreService.touchUserDoc(user.uid);
        _listenToCloudHistory(user.uid);
        _listenToCatalog(user.uid);
        _hydrateSettings(user.uid);
      } else {
        cloudHistory = [];
        userCatalog = [];
        _cloudHistorySubscription?.cancel();
        _catalogSubscription?.cancel();
      }
      notifyListeners();
    });
  }

  void _listenToCloudHistory(String userId) {
    _cloudHistorySubscription?.cancel();
    _cloudHistorySubscription = _firestoreService.getQuoteHistory(userId).listen((history) async {
      cloudHistory = history;
      // Hydrate local box with cloud history so drafts and offline support works
      for (var q in history) {
        if (!_box.containsKey(q.id) || _box.get(q.id)!.lastModified.isBefore(q.lastModified)) {
          await _box.put(q.id, q);
        }
      }
      loadLocalDrafts(); // Update dashboard drafts from hydrated box
      notifyListeners();
    });
  }

  void _listenToCatalog(String userId) {
    _catalogSubscription?.cancel();
    _catalogSubscription = _firestoreService.getCatalog(userId).listen((items) {
      // Merge with local Hive catalog to ensure all items are available
      for (var item in items) {
        if (!_catalogBox.containsKey(item.name.toLowerCase())) {
          _catalogBox.put(item.name.toLowerCase(), item);
        }
      }
      _loadLocalCatalog();
    });
  }

  Future<void> _hydrateSettings(String userId) async {
    _firestoreService.getSettings(userId).listen((settings) {
      if (settings.isNotEmpty) {
        if (settings.containsKey('companyName')) companyName = settings['companyName'];
        if (settings.containsKey('companyAddress')) companyAddress = settings['companyAddress'];
        if (settings.containsKey('companyPhone')) companyPhone = settings['companyPhone'];
        if (settings.containsKey('companyEmail')) companyEmail = settings['companyEmail'];
        if (settings.containsKey('hourlyRate')) defaultGlobalHourlyRate = settings['hourlyRate'];
        if (settings.containsKey('travelRate')) defaultGlobalTravelRate = settings['travelRate'];
        if (settings.containsKey('markupPercentage')) defaultGlobalMarkup = settings['markupPercentage'];
        if (settings.containsKey('bankName')) bankName = settings['bankName'];
        if (settings.containsKey('accountType')) accountType = settings['accountType'];
        if (settings.containsKey('accountNumber')) accountNumber = settings['accountNumber'];
        if (settings.containsKey('branchCode')) branchCode = settings['branchCode'];
        if (settings.containsKey('swiftCode')) swiftCode = settings['swiftCode'];
        
        // Persist locally
        _settingsBox.put('companyName', companyName);
        _settingsBox.put('companyAddress', companyAddress);
        _settingsBox.put('companyPhone', companyPhone);
        _settingsBox.put('companyEmail', companyEmail);
        _settingsBox.put('hourlyRate', defaultGlobalHourlyRate);
        _settingsBox.put('travelRate', defaultGlobalTravelRate);
        _settingsBox.put('markupPercentage', defaultGlobalMarkup);
        _settingsBox.put('bankName', bankName);
        _settingsBox.put('accountType', accountType);
        _settingsBox.put('accountNumber', accountNumber);
        _settingsBox.put('branchCode', branchCode);
        _settingsBox.put('swiftCode', swiftCode);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cloudHistorySubscription?.cancel();
    _catalogSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadSettings() {
    companyName = _settingsBox.get('companyName', defaultValue: '');
    companyAddress = _settingsBox.get('companyAddress', defaultValue: '');
    companyPhone = _settingsBox.get('companyPhone', defaultValue: '');
    companyEmail = _settingsBox.get('companyEmail', defaultValue: '');
    defaultGlobalHourlyRate = _settingsBox.get('hourlyRate', defaultValue: 350.0);
    defaultGlobalTravelRate = _settingsBox.get('travelRate', defaultValue: 8.5);
    defaultGlobalMarkup = _settingsBox.get('markupPercentage', defaultValue: 15.0);
    bankName = _settingsBox.get('bankName', defaultValue: '');
    accountType = _settingsBox.get('accountType', defaultValue: '');
    accountNumber = _settingsBox.get('accountNumber', defaultValue: '');
    branchCode = _settingsBox.get('branchCode', defaultValue: '');
    swiftCode = _settingsBox.get('swiftCode', defaultValue: '');
    isDarkMode = _settingsBox.get('isDarkMode', defaultValue: true);
    final syncMs = _settingsBox.get('lastSyncedAt');
    if (syncMs != null) lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(syncMs);
  }

  // --- Persistence Logic ---

  void loadLocalDrafts() {
    final currentUserId = currentUser?.uid;
    savedQuotes = _box.values
        .where((q) => q.status == QuoteStatus.draft && q.userId == currentUserId)
        .toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    notifyListeners();
  }

  void _loadLocalCatalog() {
    userCatalog = _catalogBox.values.toList();
    notifyListeners();
  }

  void _triggerAutoSave() {
    notifyListeners();
    
    // Auto-save debounce
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveCurrentQuote();
    });
  }

  Future<void> _saveCurrentQuote() async {
    // Only save if there's actual data
    if (clientName.isEmpty && 
        projectTitle.isEmpty &&
        estimatedHours == 0 && 
        materials.isEmpty && 
        travelDistanceKm == 0 && 
        flatTravelFee == 0 &&
        photoPaths.isEmpty) {
      return; 
    }

    currentQuoteId ??= const Uuid().v4();

    final model = QuoteModel(
        id: currentQuoteId!,
        clientName: clientName.isEmpty ? 'Draft Quote' : clientName,
        projectTitle: projectTitle,
        status: currentStatus,
      lastModified: DateTime.now(),
      category: selectedCategory,
      useCallOutFee: useCallOutFee,
      callOutFeeAmount: callOutFeeAmount,
      hourlyRate: hourlyRate,
      estimatedHours: estimatedHours,
      travelCostPerKm: travelCostPerKm,
      travelDistanceKm: travelDistanceKm,
      flatTravelFee: flatTravelFee,
      useFlatTravelFee: useFlatTravelFee,
      materials: List.from(materials),
      markupPercentage: markupPercentage,
      totalCostCached: totalCost,
      photoPaths: List.from(photoPaths),
      userId: currentUser?.uid,
    );

    currentQuoteId = model.id; // ensure session locks onto this draft

    await _box.put(model.id, model);
    loadLocalDrafts(); // Refresh list

    // Safely sync draft state to cloud without awaiting (fire and forget)
    if (currentUser != null) {
      _firestoreService.uploadQuote(currentUser!.uid, model).catchError((e) {
        debugPrint('Failed to sync draft to cloud: $e');
      });
    }
  }

  Future<void> markAsSent() async {
    currentStatus = QuoteStatus.sent;
    await _saveCurrentQuote();
    
    // Sync to Cloud if logged in
    if (currentUser != null && currentQuoteId != null) {
      final model = _box.get(currentQuoteId!);
      if (model != null) {
        await _firestoreService.uploadQuote(currentUser!.uid, model);
        // Once synced to cloud, we can remove from local drafts if desired,
        // but for now we'll keep it local too. The Dashboard will filter them.
      }
    }
  }

  Future<void> updateQuoteStatus(QuoteModel quote, QuoteStatus newStatus) async {
    if (currentUser == null) return;
    
    quote.status = newStatus;
    quote.lastModified = DateTime.now();

    // If it exists locally, update it there too
    if (_box.containsKey(quote.id)) {
      await _box.put(quote.id, quote);
      loadLocalDrafts();
    }

    // Sync to Firestore
    await _firestoreService.uploadQuote(currentUser!.uid, quote);
  }

  Future<void> deleteQuote(String id) async {
    final quote = _box.get(id);
    if (quote != null) {
      // Cleanup photos
      for (var photoPath in quote.photoPaths) {
        try {
          final file = File(photoPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting photo: $e');
        }
      }
      await _box.delete(id);
      loadLocalDrafts();
    }
  }

  Future<void> clearAllData() async {
    // delete all photo files first
    for (var quote in _box.values) {
      for (var path in quote.photoPaths) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) { /* ignore */ }
      }
    }
    await _box.clear();
    await _settingsBox.clear();
    _loadSettings(); // reset to defaults
    resetSession();
    loadLocalDrafts();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // --- Google Drive Actions ---

  Future<String?> linkGoogleDrive() async {
    final error = await _driveAuthService.signInWithGoogle();
    notifyListeners();
    return error;
  }

  Future<void> unlinkGoogleDrive() async {
    await _driveAuthService.signOut();
    notifyListeners();
  }

  Future<String?> createDriveBackupFolder() async {
    final folderId = await _driveAuthService.createBackupFolder();
    notifyListeners();
    return folderId;
  }

  // --- OneDrive Actions ---

  Future<String?> linkOneDrive() async {
    final error = await _oneDriveAuthService.signInWithMicrosoft();
    notifyListeners();
    return error;
  }

  Future<void> unlinkOneDrive() async {
    await _oneDriveAuthService.signOut();
    notifyListeners();
  }

  // --- Image Logic ---

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Optimize size
      );

      if (pickedFile != null) {
        final String savedPath = await _saveImageToDocuments(pickedFile);
        photoPaths.add(savedPath);
        _triggerAutoSave();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<String> _saveImageToDocuments(XFile pickedFile) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String photosDirPath = path.join(appDir.path, 'quote_photos');
    final Directory photosDir = Directory(photosDirPath);

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final String extension = path.extension(pickedFile.path);
    final String fileName = 'img_$timestamp${DateTime.now().millisecond}$extension';
    final String savedPath = path.join(photosDirPath, fileName);

    await File(pickedFile.path).copy(savedPath);
    return savedPath;
  }

  void removePhoto(int index) async {
    if (index >= 0 && index < photoPaths.length) {
      final String photoPath = photoPaths[index];
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting photo file: $e');
      }
      photoPaths.removeAt(index);
      _triggerAutoSave();
    }
  }

  // --- Actions ---

  void loadQuoteIntoSession(QuoteModel quote) {
    currentQuoteId = quote.id;
    clientName = quote.clientName;
    projectTitle = quote.projectTitle;
    currentStatus = quote.status;
    selectedCategory = quote.category;
    useCallOutFee = quote.useCallOutFee;
    callOutFeeAmount = quote.callOutFeeAmount;
    hourlyRate = quote.hourlyRate;
    estimatedHours = quote.estimatedHours;
    travelCostPerKm = quote.travelCostPerKm;
    travelDistanceKm = quote.travelDistanceKm;
    flatTravelFee = quote.flatTravelFee;
    useFlatTravelFee = quote.useFlatTravelFee;
    materials = List.from(quote.materials);
    markupPercentage = quote.markupPercentage;
    photoPaths = List.from(quote.photoPaths);
    notifyListeners();
  }

  void updateClientName(String name) {
    clientName = name;
    _triggerAutoSave();
  }

  void updateProjectTitle(String title) {
    projectTitle = title;
    _triggerAutoSave();
  }

  void setCategory(TradeCategory category) {
    selectedCategory = category;
    final info = TradeCategoryInfo.fromCategory(category);
    callOutFeeAmount = info.defaultCallOutFee;
    
    // Use global default if set, otherwise use trade default
    hourlyRate = defaultGlobalHourlyRate; 
    _triggerAutoSave();
  }

  void updateGlobalSettings({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required double hourlyRate,
    required double travelRate,
    required double markup,
    required String bankName,
    required String accountType,
    required String accountNumber,
    required String branchCode,
    required String swiftCode,
  }) {
    this.companyName = companyName;
    this.companyAddress = companyAddress;
    this.companyPhone = companyPhone;
    this.companyEmail = companyEmail;
    defaultGlobalHourlyRate = hourlyRate;
    defaultGlobalTravelRate = travelRate;
    defaultGlobalMarkup = markup;
    this.bankName = bankName;
    this.accountType = accountType;
    this.accountNumber = accountNumber;
    this.branchCode = branchCode;
    this.swiftCode = swiftCode;
    
    _settingsBox.put('companyName', companyName);
    _settingsBox.put('companyAddress', companyAddress);
    _settingsBox.put('companyPhone', companyPhone);
    _settingsBox.put('companyEmail', companyEmail);
    _settingsBox.put('hourlyRate', hourlyRate);
    _settingsBox.put('travelRate', travelRate);
    _settingsBox.put('markupPercentage', markup);
    _settingsBox.put('bankName', bankName);
    _settingsBox.put('accountType', accountType);
    _settingsBox.put('accountNumber', accountNumber);
    _settingsBox.put('branchCode', branchCode);
    _settingsBox.put('swiftCode', swiftCode);
    notifyListeners();

    if (currentUser != null) {
      _firestoreService.uploadSettings(currentUser!.uid, {
        'companyName': companyName,
        'companyAddress': companyAddress,
        'companyPhone': companyPhone,
        'companyEmail': companyEmail,
        'hourlyRate': hourlyRate,
        'travelRate': travelRate,
        'markupPercentage': markup,
        'bankName': bankName,
        'accountType': accountType,
        'accountNumber': accountNumber,
        'branchCode': branchCode,
        'swiftCode': swiftCode,
      });
    }
  }

  void updateCallOutFee(bool applyFee, double feeAmount) {
    useCallOutFee = applyFee;
    callOutFeeAmount = feeAmount;
    _triggerAutoSave();
  }

  void updateLabor(double rate, double hours) {
    hourlyRate = rate;
    estimatedHours = hours;
    _triggerAutoSave();
  }

  void updateTravelDistanceBased(double costPerKm, double distanceKm) {
    useFlatTravelFee = false;
    travelCostPerKm = costPerKm;
    travelDistanceKm = distanceKm;
    _triggerAutoSave();
  }

  void updateTravelFlatFee(double fee) {
    useFlatTravelFee = true;
    flatTravelFee = fee;
    _triggerAutoSave();
  }

  void updateMarkup(double percentage) {
    markupPercentage = percentage < 0 ? 0 : percentage;
    _triggerAutoSave();
  }

  void addMaterial(MaterialItem item) {
    materials.add(item);
    saveToCatalog(item.name, item.cost, selectedCategory);
    _triggerAutoSave();
  }

  Future<void> saveToCatalog(String name, double cost, TradeCategory category) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;

    final key = normalizedName.toLowerCase().replaceAll(' ', '_');
    
    // Check if it already exists in hardcoded quickMaterials (we don't need to save those)
    final tradeInfo = TradeCategoryInfo.fromCategory(category);
    final isHardcoded = tradeInfo.quickMaterials.any(
      (m) => m.name.toLowerCase() == normalizedName.toLowerCase()
    );
    if (isHardcoded) return;

    // Check if already in user catalog
    if (!_catalogBox.containsKey(key)) {
      final newItem = CatalogItem(
        name: normalizedName,
        defaultCost: cost,
        category: category,
      );
      
      await _catalogBox.put(key, newItem);
      _loadLocalCatalog();

      // Sync to Firestore if logged in
      if (currentUser != null) {
        await _firestoreService.uploadCatalogItem(currentUser!.uid, newItem);
      }
    }
  }

  void removeMaterial(String id) {
    materials.removeWhere((m) => m.id == id);
    _triggerAutoSave();
  }

  // --- Getters & Calculations ---

  double get laborCost => hourlyRate * estimatedHours;

  double get travelCost => useFlatTravelFee ? flatTravelFee : (travelCostPerKm * travelDistanceKm);

  double get baseMaterialsCost {
    return materials.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  double get materialsMarkupCost {
    return baseMaterialsCost * (markupPercentage / 100);
  }

  double get totalMaterialsCost => baseMaterialsCost + materialsMarkupCost;

  double get callOutCost => useCallOutFee ? callOutFeeAmount : 0.0;

  double get totalCost {
    final cost = callOutCost + laborCost + travelCost + totalMaterialsCost;
    return cost < 0 ? 0 : cost;
  }
  
  void resetSession() {
    currentQuoteId = null;
    clientName = '';
    projectTitle = '';
    currentStatus = QuoteStatus.draft;
    useCallOutFee = false;
    
    // Reset to global business defaults
    hourlyRate = defaultGlobalHourlyRate; 
    travelCostPerKm = defaultGlobalTravelRate;
    markupPercentage = defaultGlobalMarkup;
    
    estimatedHours = 0.0;
    travelDistanceKm = 0.0;
    flatTravelFee = 0.0;
    useFlatTravelFee = false;
    materials = [];
    materials = [];
    photoPaths = [];
    notifyListeners();
  }

  // --- Firestore Specifics ---
  
  Future<void> manualSyncQuote(QuoteModel quote) async {
    if (currentUser != null) {
      await _firestoreService.uploadQuote(currentUser!.uid, quote);
    }
  }

  Future<void> deleteQuoteFromCloud(String firestoreId) async {
    if (currentUser != null) {
      await _firestoreService.deleteQuote(currentUser!.uid, firestoreId);
    }
  }

  /// Forces a full re-sync of all local quotes and settings to Firestore.
  /// Performs a get() + set() on each quote to clear any SDK-cached permission errors.
  Future<Map<String, dynamic>> forceSyncAll() async {
    if (currentUser == null) return {'success': 0, 'failed': 0, 'error': 'Not logged in'};

    final allLocalQuotes = _box.values.toList();
    final result = await _firestoreService.forceSyncQuotes(currentUser!.uid, allLocalQuotes);

    // Also push settings
    await _firestoreService.uploadSettings(currentUser!.uid, {
      'companyName': companyName,
      'companyAddress': companyAddress,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
      'hourlyRate': defaultGlobalHourlyRate,
      'travelRate': defaultGlobalTravelRate,
      'markupPercentage': defaultGlobalMarkup,
      'bankName': bankName,
      'accountType': accountType,
      'accountNumber': accountNumber,
      'branchCode': branchCode,
      'swiftCode': swiftCode,
    });

    return result;
  }

  /// Atomic batch sync of all local data to Firestore
  Future<void> syncAllLocalDataToCloud() async {
    if (currentUser == null) return;
    
    isSyncing = true;
    notifyListeners();

    try {
      final allQuotes = _box.values.toList();
      final allCatalog = _catalogBox.values.toList();
      final settings = {
        'companyName': companyName,
        'companyAddress': companyAddress,
        'companyPhone': companyPhone,
        'companyEmail': companyEmail,
        'hourlyRate': defaultGlobalHourlyRate,
        'travelRate': defaultGlobalTravelRate,
        'markupPercentage': defaultGlobalMarkup,
        'bankName': bankName,
        'accountType': accountType,
        'accountNumber': accountNumber,
        'branchCode': branchCode,
        'swiftCode': swiftCode,
      };

      await _firestoreService.syncAllData(
        userId: currentUser!.uid,
        quotes: allQuotes,
        catalog: allCatalog,
        settings: settings,
      );

      lastSyncedAt = DateTime.now();
      await _settingsBox.put('lastSyncedAt', lastSyncedAt!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Full sync failed: $e');
      rethrow;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // --- Theme Mode Logic ---
  
  void toggleThemeMode() {
    isDarkMode = !isDarkMode;
    _settingsBox.put('isDarkMode', isDarkMode);
    notifyListeners();
  }

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;
}
