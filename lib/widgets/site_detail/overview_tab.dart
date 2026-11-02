import 'package:flutter/material.dart';
import 'stat_card.dart';

class OverviewTab extends StatelessWidget {
  final String siteName;
  final String workType;
  final String status;

  final int invoiceCount;

  final double totalInvoiced;
  final double totalPaid;
  final double totalOutstanding;

  const OverviewTab({
    super.key,
    required this.siteName,
    required this.workType,
    required this.status,
    required this.invoiceCount,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        Text(
          siteName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        Text(
          'Work Type: $workType',
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 10),

        Text(
          'Status: $status',
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 20),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            StatCard(
              title: 'Invoices',
              value: invoiceCount.toString(),
            ),
            StatCard(
              title: 'Invoiced',
              value: '₹${totalInvoiced.toStringAsFixed(0)}',
            ),
            StatCard(
              title: 'Paid',
              value: '₹${totalPaid.toStringAsFixed(0)}',
            ),
            StatCard(
              title: 'Outstanding',
              value: '₹${totalOutstanding.toStringAsFixed(0)}',
            ),
          ],
        ),
      ],
    );
  }
}