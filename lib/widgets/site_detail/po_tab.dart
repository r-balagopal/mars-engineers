import 'package:flutter/material.dart';
import '../../services/pdf_opener.dart';

import '../../models/invoice.dart';
import '../../models/work_order.dart';
import '../../utils/format.dart';

class PoTab extends StatelessWidget {
  final List<WorkOrder> pos;
  final List<Invoice> invoices;
  final void Function(WorkOrder) onEdit;
  final void Function(WorkOrder) onDelete;

  const PoTab({
    super.key,
    required this.pos,
    required this.invoices,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (pos.isEmpty) {
      return const Center(
        child: Text('No POs yet', style: TextStyle(fontSize: 18)),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pos.length,
      itemBuilder: (context, i) {
        final po = pos[i];
        final billed = invoices
            .where((inv) => inv.poId == po.id)
            .fold<double>(0, (sum, inv) => sum + inv.amount);
        final value = po.poValue;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        po.label.isEmpty ? 'PO' : 'PO ${po.label}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (po.hasFile)
                      IconButton(
                        tooltip: 'Open PO file',
                        icon: const Icon(Icons.picture_as_pdf),
                        onPressed: () => openFile(po.filePath),
                      ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(po),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(po),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (value == null)
                  Text(
                    'Old PO file: tap Edit to add the PO number and value',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else ...[
                  Text(
                    '${inrFull(value)} · ${fmtIso(po.poDate)} · '
                    '${po.paymentTermsDays} day terms',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value > 0 ? (billed / value).clamp(0.0, 1.0) : 0,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Billed ${inrFull(billed)} · '
                    'Balance ${inrFull((value - billed).clamp(0, double.infinity).toDouble())}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
