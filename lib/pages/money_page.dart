import 'package:flutter/material.dart';

import 'gst_returns_tab.dart';
import 'invoices_page.dart';

/// Money: invoices and the monthly GSTR-3B returns.
class MoneyPage extends StatelessWidget {
  const MoneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Money'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Invoices'),
              Tab(text: 'GST (GSTR-3B)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            InvoicesPage(),
            GstReturnsTab(),
          ],
        ),
      ),
    );
  }
}
