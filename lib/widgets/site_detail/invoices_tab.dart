import 'package:flutter/material.dart';

import '../../models/invoice.dart';

class InvoicesTab extends StatelessWidget {
  final List<Invoice> invoices;
  final Function(Invoice) onInvoiceTap;

  const InvoicesTab({
    super.key,
    required this.invoices,
    required this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(
        child: Text(
          'No invoices yet',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.receipt_long),

            title: Text(invoice.invoiceNumber),

            subtitle: Text(
              '₹${invoice.amount.toStringAsFixed(0)} • ${invoice.status}',
            ),

            trailing: const Icon(Icons.chevron_right),

            onTap: () => onInvoiceTap(invoice),
          ),
        );
      },
    );
  }
}