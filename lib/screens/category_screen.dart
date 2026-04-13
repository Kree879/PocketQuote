import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trade_category.dart';
import '../state/quote_state.dart';
import '../widgets/glass_container.dart';
import 'costing_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Category'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What type of job is this?',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Select a trade to apply industry-specific settings and defaults.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: TradeCategory.values.length,
                  itemBuilder: (context, index) {
                    final category = TradeCategory.values[index];
                    final info = TradeCategoryInfo.fromCategory(category);

                    return GestureDetector(
                      onTap: () {
                        context.read<QuoteState>().setCategory(category);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CostingScreen()),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Glow Effect
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: info.glowColor.withAlpha(102), // 0.4 * 255 (was 15%)
                                    blurRadius: 25,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Glass Card
                          GlassContainer(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: info.glowColor.withAlpha(77), // 0.3 * 255 (was 10%)
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: info.getDisplayColor(context).withAlpha(80),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    info.icon,
                                    size: 40,
                                    color: info.getDisplayColor(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  info.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
