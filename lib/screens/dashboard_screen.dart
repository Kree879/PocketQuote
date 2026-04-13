import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/quote_state.dart';
import '../models/quote_model.dart';
import '../models/trade_category.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'category_screen.dart';
import 'costing_screen.dart';

import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  void _confirmDelete(BuildContext context, QuoteState state, String id, String clientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Delete Quote'),
        content: Text('Are you sure you want to delete the quote for "$clientName"? This will also remove all associated photos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.deleteQuote(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            context.read<QuoteState>().signOut();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<QuoteState>(
          builder: (context, state, child) {
            final drafts = state.savedQuotes; // and we updated state to filter drafts locally
            final history = state.jobHistory;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting ${state.currentUser?.email?.split('@').first ?? 'Partner'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pocket Quote',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 32),
                  
                  // New Quote Action
                  GlassContainer(
                    onTap: () {
                      state.resetSession();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CategoryScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withAlpha(51), // 20% of 255
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_circle, color: AppTheme.accentColor, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create New Quote', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('Calculate costs and save drafts', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Theme.of(context).textTheme.bodyMedium?.color),
                      ],
                    ),
                  ),
                  
                  // Recent Drafts (Horizontal Scroll)
                  if (drafts.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text('Active Local Drafts', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: drafts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final draft = drafts[index];
                          final catInfo = TradeCategoryInfo.fromCategory(draft.category);

                          return SizedBox(
                            width: 240,
                            child: GlassContainer(
                              onTap: () {
                                state.loadQuoteIntoSession(draft);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CostingScreen()),
                                );
                              },
                              onLongPress: () => _confirmDelete(
                                context, 
                                state, 
                                draft.id, 
                                draft.clientName.isEmpty ? 'Draft Quote' : draft.clientName
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          draft.clientName.isEmpty ? 'Draft Quote' : draft.clientName,
                                          style: Theme.of(context).textTheme.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(isDark ? 51 : 30),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('Draft', style: TextStyle(color: isDark ? Colors.orangeAccent : Colors.orange.shade800, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(catInfo.icon, size: 16, color: catInfo.getDisplayColor(context)),
                                      const SizedBox(width: 4),
                                      Text(catInfo.title, style: TextStyle(color: catInfo.getDisplayColor(context), fontSize: 12)),
                                      if (draft.photoPaths.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.camera_alt, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                                        const SizedBox(width: 2),
                                        Text('${draft.photoPaths.length}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 10)),
                                      ],
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${state.currencySymbol}${draft.totalCostCached.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppTheme.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Modified: ${DateFormat('MMM dd, HH:mm').format(draft.lastModified)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text('Job History', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accentColor)),
                  const SizedBox(height: 16),
                  
                  // History List
                  if (history.isEmpty)
                    Text(
                      'No jobs yet. Mark a quote as "Sent" to see it here.', 
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black38)
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final quote = history[index];
                          return GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            onTap: () {
                              state.loadQuoteIntoSession(quote);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CostingScreen()),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quote.projectTitle.isNotEmpty ? quote.projectTitle : (quote.clientName.isEmpty ? 'Quote #${quote.firestoreId?.substring(0, 5)}' : quote.clientName),
                                      style: Theme.of(context).textTheme.titleMedium
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(DateFormat('MMM dd, yyyy').format(quote.lastModified), style: Theme.of(context).textTheme.bodyMedium),
                                        const SizedBox(width: 8),
                                        if (state.cloudHistory.any((c) => c.id == quote.id))
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentColor.withAlpha(30),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Cloud', style: TextStyle(color: AppTheme.accentColor, fontSize: 10)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${state.currencySymbol}${quote.totalCostCached.toStringAsFixed(2)}', 
                                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                         )),
                                    const SizedBox(height: 4),
                                    Text(
                                      quote.status.name.toUpperCase(),
                                      style: TextStyle(
                                        color: quote.status == QuoteStatus.completed ? AppTheme.accentColor : Theme.of(context).textTheme.bodySmall?.color?.withAlpha(97),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
