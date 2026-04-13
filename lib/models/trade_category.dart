import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'trade_category.g.dart';

@HiveType(typeId: 0)
enum TradeCategory {
  @HiveField(0)
  electrical,
  @HiveField(1)
  plumbing,
  @HiveField(2)
  pool,
  @HiveField(3)
  garden,
  @HiveField(4)
  handyman,
  @HiveField(5)
  general
}

class CommonMaterial {
  final String name;
  final double cost;
  const CommonMaterial(this.name, this.cost);
}

class TradeCategoryInfo {
  final TradeCategory type;
  final String title;
  final IconData icon;
  final Color glowColor;
  final String materialLabel;
  final String materialHint;
  final String laborDescription;
  final double defaultCallOutFee;
  final double defaultHourlyRateZar;
  final List<CommonMaterial> quickMaterials;

  const TradeCategoryInfo({
    required this.type,
    required this.title,
    required this.icon,
    required this.glowColor,
    required this.materialLabel,
    required this.materialHint,
    required this.laborDescription,
    required this.defaultCallOutFee,
    required this.defaultHourlyRateZar,
    required this.quickMaterials,
  });

  Color getDisplayColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return glowColor;
    
    // For light mode, we want a vibrant version of the glow color
    final hsl = HSLColor.fromColor(glowColor);
    // Darken by only 15% (was 25%) and increase saturation for more vibrancy in light mode
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 0.6))
              .withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0))
              .toColor();
  }

  static TradeCategoryInfo fromCategory(TradeCategory category) {
    switch (category) {
      case TradeCategory.electrical:
        return const TradeCategoryInfo(
          type: TradeCategory.electrical,
          title: 'Electrical',
          icon: Icons.electrical_services,
          glowColor: Colors.amber,
          materialLabel: 'Consumables / Wire',
          materialHint: 'Add tape, wire nuts, cable, etc.',
          laborDescription: 'Installation, testing & commissioning',
          defaultCallOutFee: 85.0,
          defaultHourlyRateZar: 650.0,
          quickMaterials: [
            CommonMaterial('Twin & Earth (2.5mm)', 25.00),
            CommonMaterial('1-Way Switch', 45.00),
            CommonMaterial('13A Wall Socket', 85.00),
            CommonMaterial('PVC Tape', 12.00),
            CommonMaterial('20mm Conduit (4m)', 65.00),
          ],
        );
      case TradeCategory.plumbing:
        return const TradeCategoryInfo(
          type: TradeCategory.plumbing,
          title: 'Plumbing',
          icon: Icons.plumbing,
          glowColor: Colors.blueAccent,
          materialLabel: 'Parts & Consumables',
          materialHint: 'Add pipes, fittings, solder, etc.',
          laborDescription: 'Installation & testing',
          defaultCallOutFee: 75.0,
          defaultHourlyRateZar: 600.0,
          quickMaterials: [
            CommonMaterial('Copper Pipe (15mm)', 85.00),
            CommonMaterial('Elbow Fitting', 15.00),
            CommonMaterial('PTFE Tape', 10.00),
            CommonMaterial('Tap Washer Set', 25.00),
            CommonMaterial('PVC Solvent (100ml)', 45.00),
          ],
        );
      case TradeCategory.pool:
        return const TradeCategoryInfo(
          type: TradeCategory.pool,
          title: 'Pool Service',
          icon: Icons.pool,
          glowColor: Colors.cyanAccent,
          materialLabel: 'Chemicals / Parts',
          materialHint: 'Add chlorine, acid, filters, etc.',
          laborDescription: 'Service & maintenance',
          defaultCallOutFee: 50.0,
          defaultHourlyRateZar: 450.0,
          quickMaterials: [
            CommonMaterial('Chlorine (5kg)', 245.00),
            CommonMaterial('HTH Shock', 85.00),
            CommonMaterial('Pool Acid (5L)', 45.00),
            CommonMaterial('Weir Basket', 120.00),
            CommonMaterial('Pool Hose (per section)', 110.00),
          ],
        );
      case TradeCategory.garden:
        return const TradeCategoryInfo(
          type: TradeCategory.garden,
          title: 'Garden & Landscaping',
          icon: Icons.local_florist,
          glowColor: Colors.greenAccent,
          materialLabel: 'Soil / Fertilizer / Plants',
          materialHint: 'Add soils, compost, seeds, etc.',
          laborDescription: 'Labor & clearing',
          defaultCallOutFee: 45.0,
          defaultHourlyRateZar: 350.0,
          quickMaterials: [
            CommonMaterial('Potting Soil (30L)', 65.00),
            CommonMaterial('Fertilizer (2kg)', 110.00),
            CommonMaterial('Grass Seed (1kg)', 75.00),
            CommonMaterial('Mulch Bag', 55.00),
            CommonMaterial('Bedding Plants (Tray)', 120.00),
          ],
        );
      case TradeCategory.handyman:
        return const TradeCategoryInfo(
          type: TradeCategory.handyman,
          title: 'Handyman',
          icon: Icons.handyman,
          glowColor: Colors.orangeAccent,
          materialLabel: 'Hardware / Materials',
          materialHint: 'Add screws, paint, wood, etc.',
          laborDescription: 'Installation & repairs',
          defaultCallOutFee: 65.0,
          defaultHourlyRateZar: 400.0,
          quickMaterials: [
            CommonMaterial('Wood Screws (Pack)', 45.00),
            CommonMaterial('Wood Glue', 35.00),
            CommonMaterial('Sandpaper (Multi)', 25.00),
            CommonMaterial('Paint Brush (50mm)', 40.00),
            CommonMaterial('Wall Plugs (Pack)', 30.00),
          ],
        );
      case TradeCategory.general:
        return const TradeCategoryInfo(
          type: TradeCategory.general,
          title: 'General / Custom',
          icon: Icons.design_services,
          glowColor: Colors.grey,
          materialLabel: 'Materials',
          materialHint: 'Add specific job materials',
          laborDescription: 'General labor',
          defaultCallOutFee: 50.0,
          defaultHourlyRateZar: 350.0,
          quickMaterials: [
            CommonMaterial('Delivery Fee', 150.00),
            CommonMaterial('Small Hardware Fee', 50.00),
            CommonMaterial('Admin/Fee', 100.00),
          ],
        );
    }
  }
}
