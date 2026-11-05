import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../models/work_order.dart';
import '../../utils/format.dart';
import '../status_pill.dart';

/// Overdue = still money to collect and past invoice date + PO terms (30 days
/// if the invoice isn't linked to a PO).
bool isInvoiceOverdue(Invoice inv, List<WorkOrder> pos) {
  if (inv.balance <= 0.5) return false;
  final date = DateTime.tryParse(inv.invoiceDate ?? '');
  if (date == null) return false;
  var terms = 30;
  for (final po in pos) {
    if (po.id == inv.poId) terms = po.paymentTermsDays;
  }
  return DateTime.now().isAfter(date.add(Duration(days: terms)));
}

class InvoicesTab extends StatelessWidget {
  final List<Invoice> invoices;
  final List<WorkOrder> pos;
  final Function(Invoice) onInvoiceTap;

  const InvoicesTab({
    super.key,
    required this.invoices,
    required this.pos,
    required this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(
        child: Text('No invoices yet', style: TextStyle(fontSize: 18)),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        final overdue = isInvoiceOverdue(inv, pos);

        String? poLabel;
        for (final po in pos) {
          if (po.id == inv.poId) poLabel = po.label;
        }

        final parts = <String>[
          inrFull(inv.amount),
          if (inv.status == 'Part paid') 'paid ${inrFull(inv.paid)}',
          if (poLabel != null) 'PO $poLabel',
          fmtIso(inv.invoiceDate),
        ];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(inv.invoiceNumber),
            subtitle: Text(parts.join(' · ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusPill(overdue ? 'Overdue' : inv.status),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => onInvoiceTap(inv),
          ),
        );
      },
    );
  }
}
