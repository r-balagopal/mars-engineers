import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../models/work_order.dart';
import '../../models/site.dart';
import '../../utils/format.dart';
import '../status_pill.dart';
import 'invoices_tab.dart';

class OverviewTab extends StatelessWidget {
  final Site site;
  final List<WorkOrder> pos;
  final List<Invoice> invoices;

  const OverviewTab({
    super.key,
    required this.site,
    required this.pos,
    required this.invoices,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final poValue = pos.fold<double>(0, (s, p) => s + (p.poValue ?? 0));
    final invoiced = invoices.fold<double>(0, (s, i) => s + i.amount);
    final paid = invoices.fold<double>(0, (s, i) => s + i.paid);
    final toBill = (poValue - invoiced).clamp(0, double.infinity).toDouble();
    final outstanding = invoiced - paid;
    final percent = poValue > 0 ? (invoiced / poValue).clamp(0.0, 1.0) : 0.0;

    final cards = [
      ('PO value', inr(poValue)),
      ('Invoiced', inr(invoiced)),
      ('Paid', inr(paid)),
      ('Balance to bill', inr(toBill)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(site.workType,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            StatusPill(site.status),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 4 : 2;
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: w,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.$1,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(card.$2,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (poValue > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent, minHeight: 8),
          ),
          const SizedBox(height: 6),
          Text(
            '${(percent * 100).round()}% of PO value billed · '
            'outstanding from client ${inrFull(outstanding)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ] else
          Text(
            'Add a PO (POs tab) to track billing against it.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 20),
        Text('Recent invoices',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        if (invoices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No invoices yet'),
          )
        else
          for (final inv in invoices.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long),
              title: Text(inv.invoiceNumber),
              subtitle: Text('${fmtIso(inv.invoiceDate)} · ${inrFull(inv.amount)}'),
              trailing:
                  StatusPill(isInvoiceOverdue(inv, pos) ? 'Overdue' : inv.status),
            ),
      ],
    );
  }
}
