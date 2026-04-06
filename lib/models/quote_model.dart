import 'package:hive/hive.dart';
import 'material_item.dart';
import 'trade_category.dart';

part 'quote_model.g.dart';

@HiveType(typeId: 2)
enum QuoteStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  sent,
  @HiveField(2)
  approved,
  @HiveField(3)
  inProgress, // Matches "Printing" in the example
  @HiveField(4)
  completed,
  @HiveField(5)
  invoiced,
  @HiveField(6)
  paid
}

@HiveType(typeId: 3)
class QuoteModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String clientName;
  @HiveField(2)
  QuoteStatus status;
  @HiveField(3)
  DateTime lastModified;
  
  @HiveField(4)
  TradeCategory category;
  @HiveField(5)
  bool useCallOutFee;
  @HiveField(6)
  double callOutFeeAmount;

  @HiveField(7)
  double hourlyRate;
  @HiveField(8)
  double estimatedHours;

  @HiveField(9)
  double travelCostPerKm;
  @HiveField(10)
  double travelDistanceKm;
  @HiveField(11)
  double flatTravelFee;
  @HiveField(12)
  bool useFlatTravelFee;

  @HiveField(13)
  List<MaterialItem> materials;
  @HiveField(14)
  double markupPercentage;
  @HiveField(15)
  double totalCostCached;
  
  @HiveField(16)
  List<String> photoPaths;

  @HiveField(18)
  final String projectTitle;

  @HiveField(19)
  String? firestoreId;

  QuoteModel({
    required this.id,
    required this.clientName,
    required this.status,
    required this.lastModified,
    required this.category,
    this.useCallOutFee = false,
    this.callOutFeeAmount = 0.0,
    this.hourlyRate = 0.0,
    this.estimatedHours = 0.0,
    this.travelCostPerKm = 0.0,
    this.travelDistanceKm = 0.0,
    this.flatTravelFee = 0.0,
    this.useFlatTravelFee = false,
    this.materials = const [],
    this.markupPercentage = 0.0,
    this.totalCostCached = 0.0,
    this.photoPaths = const [],
    this.projectTitle = '',
    this.firestoreId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientName': clientName,
      'status': status.name,
      'lastModified': lastModified.toIso8601String(),
      'category': category.name,
      'useCallOutFee': useCallOutFee,
      'callOutFeeAmount': callOutFeeAmount,
      'hourlyRate': hourlyRate,
      'estimatedHours': estimatedHours,
      'travelCostPerKm': travelCostPerKm,
      'travelDistanceKm': travelDistanceKm,
      'flatTravelFee': flatTravelFee,
      'useFlatTravelFee': useFlatTravelFee,
      'materials': materials.map((m) => m.toJson()).toList(),
      'markupPercentage': markupPercentage,
      'totalCostCached': totalCostCached,
      'photoPaths': photoPaths,
      'projectTitle': projectTitle,
      'firestoreId': firestoreId,
    };
  }

  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    return QuoteModel(
      id: json['id'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      status: QuoteStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String?), 
          orElse: () => QuoteStatus.draft),
      lastModified: DateTime.parse(json['lastModified'] as String? ?? DateTime.now().toIso8601String()),
      category: TradeCategory.values.firstWhere(
          (e) => e.name == (json['category'] as String?), 
          orElse: () => TradeCategory.general),
      useCallOutFee: json['useCallOutFee'] as bool? ?? false,
      callOutFeeAmount: (json['callOutFeeAmount'] ?? 0.0).toDouble(),
      hourlyRate: (json['hourlyRate'] ?? 0.0).toDouble(),
      estimatedHours: (json['estimatedHours'] ?? 0.0).toDouble(),
      travelCostPerKm: (json['travelCostPerKm'] ?? 0.0).toDouble(),
      travelDistanceKm: (json['travelDistanceKm'] ?? 0.0).toDouble(),
      flatTravelFee: (json['flatTravelFee'] ?? 0.0).toDouble(),
      useFlatTravelFee: json['useFlatTravelFee'] as bool? ?? false,
      materials: (json['materials'] as List<dynamic>?)
              ?.map((item) => MaterialItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      markupPercentage: (json['markupPercentage'] ?? 0.0).toDouble(),
      totalCostCached: (json['totalCostCached'] ?? 0.0).toDouble(),
      photoPaths: (json['photoPaths'] as List<dynamic>?)?.cast<String>().toList() ?? [],
      projectTitle: json['projectTitle'] as String? ?? '',
      firestoreId: json['firestoreId'] as String?,
    );
  }
}
