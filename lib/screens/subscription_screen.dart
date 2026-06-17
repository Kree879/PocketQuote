import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/subscription_provider.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isSubscribed = subProvider.isSubscribed;
    final isLoading = subProvider.isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
              const Color(0xFF0A1128),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSubscribed ? 'Business Plan Active' : 'Upgrade to Business',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take your quoting to the next level with professional tools and cloud features.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withAlpha(200),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildPlanCard(
                        context: context,
                        title: 'Free Plan',
                        price: 'Current',
                        isHighlighted: false,
                        features: [
                          'Full Math Calculator access',
                          'Generate maximum 2 Quote PDFs',
                          'Local draft saving',
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (subProvider.products.isNotEmpty)
                        ...subProvider.products.map((product) => _buildPlanCard(
                              context: context,
                              title: 'Business Plan',
                              price: product.price,
                              isHighlighted: true,
                              features: [
                                'Unlimited Quote & Invoice PDFs',
                                'Business & Jobs Management',
                                'Google Drive & OneDrive Backup',
                                'Export Catalog & History (.csv)',
                              ],
                            ))
                      else
                        _buildPlanCard(
                          context: context,
                          title: 'Business Plan',
                          price: '\$9.99/mo',
                          isHighlighted: true,
                          features: [
                            'Unlimited Quote & Invoice PDFs',
                            'Business & Jobs Management',
                            'Google Drive & OneDrive Backup',
                            'Export Catalog & History (.csv)',
                          ],
                        ),
                      const SizedBox(height: 32),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (!isSubscribed)
                        ElevatedButton(
                          onPressed: () => subProvider.purchaseBusinessPlan(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Subscribe Now'),
                        )
                      else
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('You are on the Business Plan'),
                        ),
                      const SizedBox(height: 16),
                      if (!isSubscribed && !isLoading)
                        TextButton(
                          onPressed: () => subProvider.restorePurchases(),
                          child: const Text('Restore Purchases'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required bool isHighlighted,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary.withAlpha(100)
              : Theme.of(context).colorScheme.outline.withAlpha(50),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? Theme.of(context).colorScheme.primary : null,
                    ),
              ),
              Text(
                price,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (fee) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isHighlighted ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fee,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
