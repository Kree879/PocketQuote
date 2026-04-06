// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TradeCategoryAdapter extends TypeAdapter<TradeCategory> {
  @override
  final int typeId = 0;

  @override
  TradeCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TradeCategory.electrical;
      case 1:
        return TradeCategory.plumbing;
      case 2:
        return TradeCategory.pool;
      case 3:
        return TradeCategory.garden;
      case 4:
        return TradeCategory.handyman;
      case 5:
        return TradeCategory.general;
      default:
        return TradeCategory.electrical;
    }
  }

  @override
  void write(BinaryWriter writer, TradeCategory obj) {
    switch (obj) {
      case TradeCategory.electrical:
        writer.writeByte(0);
        break;
      case TradeCategory.plumbing:
        writer.writeByte(1);
        break;
      case TradeCategory.pool:
        writer.writeByte(2);
        break;
      case TradeCategory.garden:
        writer.writeByte(3);
        break;
      case TradeCategory.handyman:
        writer.writeByte(4);
        break;
      case TradeCategory.general:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
