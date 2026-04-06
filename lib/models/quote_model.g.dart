// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuoteModelAdapter extends TypeAdapter<QuoteModel> {
  @override
  final int typeId = 3;

  @override
  QuoteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuoteModel(
      id: fields[0] as String,
      clientName: fields[1] as String,
      status: fields[2] as QuoteStatus,
      lastModified: fields[3] as DateTime,
      category: fields[4] as TradeCategory,
      useCallOutFee: fields[5] as bool,
      callOutFeeAmount: fields[6] as double,
      hourlyRate: fields[7] as double,
      estimatedHours: fields[8] as double,
      travelCostPerKm: fields[9] as double,
      travelDistanceKm: fields[10] as double,
      flatTravelFee: fields[11] as double,
      useFlatTravelFee: fields[12] as bool,
      materials: (fields[13] as List).cast<MaterialItem>(),
      markupPercentage: fields[14] as double,
      totalCostCached: fields[15] as double,
      photoPaths: (fields[16] as List).cast<String>(),
      projectTitle: fields[18] as String,
      firestoreId: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QuoteModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientName)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.useCallOutFee)
      ..writeByte(6)
      ..write(obj.callOutFeeAmount)
      ..writeByte(7)
      ..write(obj.hourlyRate)
      ..writeByte(8)
      ..write(obj.estimatedHours)
      ..writeByte(9)
      ..write(obj.travelCostPerKm)
      ..writeByte(10)
      ..write(obj.travelDistanceKm)
      ..writeByte(11)
      ..write(obj.flatTravelFee)
      ..writeByte(12)
      ..write(obj.useFlatTravelFee)
      ..writeByte(13)
      ..write(obj.materials)
      ..writeByte(14)
      ..write(obj.markupPercentage)
      ..writeByte(15)
      ..write(obj.totalCostCached)
      ..writeByte(16)
      ..write(obj.photoPaths)
      ..writeByte(18)
      ..write(obj.projectTitle)
      ..writeByte(19)
      ..write(obj.firestoreId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuoteStatusAdapter extends TypeAdapter<QuoteStatus> {
  @override
  final int typeId = 2;

  @override
  QuoteStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QuoteStatus.draft;
      case 1:
        return QuoteStatus.sent;
      case 2:
        return QuoteStatus.approved;
      case 3:
        return QuoteStatus.inProgress;
      case 4:
        return QuoteStatus.completed;
      case 5:
        return QuoteStatus.invoiced;
      case 6:
        return QuoteStatus.paid;
      default:
        return QuoteStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, QuoteStatus obj) {
    switch (obj) {
      case QuoteStatus.draft:
        writer.writeByte(0);
        break;
      case QuoteStatus.sent:
        writer.writeByte(1);
        break;
      case QuoteStatus.approved:
        writer.writeByte(2);
        break;
      case QuoteStatus.inProgress:
        writer.writeByte(3);
        break;
      case QuoteStatus.completed:
        writer.writeByte(4);
        break;
      case QuoteStatus.invoiced:
        writer.writeByte(5);
        break;
      case QuoteStatus.paid:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
