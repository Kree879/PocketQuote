import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

part 'material_item.g.dart';

@HiveType(typeId: 1)
class MaterialItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  double cost;
  @HiveField(3)
  int quantity;

  MaterialItem({
    String? id,
    required this.name,
    required this.cost,
    this.quantity = 1,
  }) : id = id ?? const Uuid().v4();

  double get totalCost => cost * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cost': cost,
      'quantity': quantity,
    };
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled Item',
      cost: (json['cost'] as num? ?? 0.0).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}
