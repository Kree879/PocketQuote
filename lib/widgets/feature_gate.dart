import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/subscription_provider.dart';

class FeatureGate extends StatelessWidget {
  final Widget child;
  final bool requiresBusiness;
  final Widget? lockedAlternative;
  final bool showLockIcon;

  const FeatureGate({
    super.key,
    required this.child,
    this.requiresBusiness = true,
    this.lockedAlternative,
    this.showLockIcon = true,
  });

  static void showUpgradePath(BuildContext context) {
    // TODO: REVERT AFTER CLOSED TESTING
    return;
    /*
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const SubscriptionScreen())
    );
    */
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    
    if (!requiresBusiness || subProvider.isSubscribed) {
      return child;
    }

    if (lockedAlternative != null) {
      return lockedAlternative!;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.5,
          child: IgnorePointer(child: child),
        ),
        if (showLockIcon)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.lock, 
              color: Theme.of(context).colorScheme.primary, 
              size: 20
            ),
          ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showUpgradePath(context),
            ),
          ),
        ),
      ],
    );
  }
}
