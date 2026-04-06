import 'package:hive/hive.dart';
import 'trade_category.dart';

part 'catalog_item.g.dart';

@HiveType(typeId: 4)
class CatalogItem extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double defaultCost;

  @HiveField(2)
  final TradeCategory category;

  CatalogItem({
    required this.name,
    required this.defaultCost,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'defaultCost': defaultCost,
      'category': category.index,
    };
  }

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      name: json['name'] as String,
      defaultCost: (json['defaultCost'] as num).toDouble(),
      category: TradeCategory.values[json['category'] as int],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          category == other.category;

  @override
  int get hashCode => name.hashCode ^ category.hashCode;
}
