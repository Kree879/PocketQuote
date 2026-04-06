import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/quote_model.dart';
import '../models/trade_category.dart';
import '../state/quote_state.dart';
import '../theme/app_theme.dart';
import '../screens/costing_screen.dart';
import '../services/pdf_service.dart';

class JobCard extends StatefulWidget {
  final QuoteModel quote;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;

  const JobCard({
    super.key, 
    required this.quote,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _isExpanded = false;

  Color _getStatusColor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.sent:
        return Colors.orangeAccent;
      case QuoteStatus.approved:
      case QuoteStatus.inProgress:
        return Colors.blueAccent;
      case QuoteStatus.completed:
      case QuoteStatus.invoiced:
        return Colors.purpleAccent;
      case QuoteStatus.paid:
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  String _getStatusLabel(QuoteStatus status) {
    if (status == QuoteStatus.sent) return 'Quoted';
    if (status == QuoteStatus.inProgress) return 'In Progress';
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  void _showDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final q = widget.quote;
        final catInfo = TradeCategoryInfo.fromCategory(q.category);
        
        final callOutCost = q.useCallOutFee ? q.callOutFeeAmount : 0.0;
        final laborCost = q.hourlyRate * q.estimatedHours;
        final travelCost = q.useFlatTravelFee ? q.flatTravelFee : (q.travelCostPerKm * q.travelDistanceKm);
        final baseMaterialCost = q.materials.fold(0.0, (sum, m) => sum + m.totalCost);
        final materialMarkupCost = baseMaterialCost * (q.markupPercentage / 100);
        final totalMaterialCost = baseMaterialCost + materialMarkupCost;
        final estimatedCost = callOutCost + laborCost + travelCost + baseMaterialCost;
        final finalPrice = q.totalCostCached; // This includes markup

        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor, // Match theme
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        q.projectTitle.isNotEmpty ? q.projectTitle : (q.clientName.isEmpty ? 'Quote #${q.id.substring(0, 5)}' : q.clientName),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color?.withAlpha(128)),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(q.status).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusLabel(q.status),
                        style: TextStyle(color: _getStatusColor(q.status), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MM/dd/yyyy, hh:mm:ss a').format(q.lastModified),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Detailed Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details Grid
                        Row(
                          children: [
                            Expanded(child: _buildDetailCol('CLIENT', q.clientName.isEmpty ? 'Unknown' : q.clientName)),
                            Expanded(child: _buildDetailCol('CATEGORY', catInfo.title, color: catInfo.glowColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDetailCol('HOURS', '${q.estimatedHours}h')),
                            Expanded(child: _buildDetailCol('DISTANCE', '${q.travelDistanceKm}km')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Costing Summary
                        _buildCostRow('Estimated Cost', estimatedCost),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Final Price', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('R${finalPrice.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Breakdowns
                        Text('COST BREAKDOWN', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (q.useCallOutFee) _buildBreakdownRow('Call Out Fee', callOutCost),
                        _buildBreakdownRow('Labor', laborCost),
                        _buildBreakdownRow('Travel', travelCost),
                        _buildBreakdownRow('Materials', totalMaterialCost),
                        if (q.markupPercentage > 0) _buildBreakdownRow('Markup (${q.markupPercentage}%)', materialMarkupCost),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (q.status == QuoteStatus.approved) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Create Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(context); // Close modal
                            final globalState = context.read<QuoteState>();
                            await PdfService.generateAndSharePDF(
                              context: context,
                              quote: q,
                              globalState: globalState,
                              isInvoice: true,
                            );
                            await globalState.updateQuoteStatus(q, QuoteStatus.invoiced);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invoice generated and status updated!')),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Load into Calculator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context); // Close modal
                          context.read<QuoteState>().loadQuoteIntoSession(q);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CostingScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCol(String title, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Theme.of(context).textTheme.bodyLarge?.color, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCostRow(String title, double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          Text('R${amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Text('R${amount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catInfo = TradeCategoryInfo.fromCategory(widget.quote.category);
    final statusColor = _getStatusColor(widget.quote.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10)) : Theme.of(context).colorScheme.surface, // Highlight if selected
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(40) : Colors.black.withAlpha(40)) : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15))),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Price Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, // center to align chevron properly
                children: [
                  if (widget.onSelectionChanged != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: widget.isSelected,
                          onChanged: (val) {
                            if (val != null) widget.onSelectionChanged!(val);
                          },
                          activeColor: AppTheme.accentColor,
                          side: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.quote.projectTitle.isNotEmpty 
                        ? widget.quote.projectTitle 
                        : (widget.quote.clientName.isEmpty ? 'Quote #${widget.quote.firestoreId?.substring(0, 5) ?? widget.quote.id.substring(0,5)}' : widget.quote.clientName),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'R${widget.quote.totalCostCached.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Theme.of(context).iconTheme.color?.withAlpha(128),
                    size: 20,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Details Row (Qty x Date | Status Tag)
              Row(
                children: [
                  Text(
                    '1x · ${DateFormat('yyyy/MM/dd').format(widget.quote.lastModified)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(widget.quote.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              if (_isExpanded) ...[
                const SizedBox(height: 12),

                // Tags Row (Client Name, Trade Category)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(Icons.person_outline, widget.quote.clientName.isEmpty ? 'Unknown' : widget.quote.clientName),
                    _buildTag(catInfo.icon, catInfo.title),
                  ],
                ),

                const SizedBox(height: 20),

                // Action Buttons Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status Dropdown Button
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withAlpha(12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<QuoteStatus>(
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).iconTheme.color?.withAlpha(178), size: 16),
                            value: widget.quote.status == QuoteStatus.draft ? QuoteStatus.sent : widget.quote.status,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            items: [
                              QuoteStatus.sent,
                              QuoteStatus.approved,
                              QuoteStatus.inProgress,
                              QuoteStatus.completed,
                              QuoteStatus.invoiced,
                              QuoteStatus.paid,
                            ].map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_getStatusLabel(status)),
                                    if (widget.quote.status == status) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check, size: 16, color: Theme.of(context).primaryColor),
                                    ]
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newStatus) {
                              if (newStatus != null) {
                                context.read<QuoteState>().updateQuoteStatus(widget.quote, newStatus);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // View Button
                      _buildActionButton(
                        icon: Icons.visibility_outlined,
                        label: 'View',
                        onTap: _showDetailsModal,
                      ),
                      const SizedBox(width: 8),

                      // Load Button
                      _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Load',
                        onTap: () {
                          context.read<QuoteState>().loadQuoteIntoSession(widget.quote);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CostingScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Delete Button
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withAlpha(40)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                title: const Text('Delete Quote'),
                                content: const Text('Are you sure you want to delete this quote?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (widget.quote.firestoreId != null) {
                                        context.read<QuoteState>().deleteQuoteFromCloud(widget.quote.firestoreId!);
                                      } else {
                                        context.read<QuoteState>().deleteQuote(widget.quote.id);
                                      }
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10), // Light glass effect
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500) ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

