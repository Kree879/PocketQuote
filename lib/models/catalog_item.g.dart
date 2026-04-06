// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CatalogItemAdapter extends TypeAdapter<CatalogItem> {
  @override
  final int typeId = 4;

  @override
  CatalogItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CatalogItem(
      name: fields[0] as String,
      defaultCost: fields[1] as double,
      category: fields[2] as TradeCategory,
    );
  }

  @override
  void write(BinaryWriter writer, CatalogItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.defaultCost)
      ..writeByte(2)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
