import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> filteredInvoices = [];

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    invoices = await DatabaseHelper.instance.getAllInvoices();
    filteredInvoices = List.from(invoices);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search invoice number, site or status',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  filteredInvoices = invoices.where((invoice) {
                    final query = value.toLowerCase();

                    return invoice['invoiceNumber']
                            .toString()
                            .toLowerCase()
                            .contains(query) ||
                        invoice['siteName']
                            .toString()
                            .toLowerCase()
                            .contains(query) ||
                        invoice['status']
                            .toString()
                            .toLowerCase()
                            .contains(query);
                  }).toList();
                });
              },
            ),
          ),

          Expanded(
            child: filteredInvoices.isEmpty
                ? const Center(
                    child: Text(
                      'No invoices found',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];

                     return ListTile(
  leading: const Icon(Icons.receipt_long),
  title: Text(invoice['invoiceNumber']),
  subtitle: Text(
    '${invoice['siteName']} • ₹${invoice['amount']} • ${invoice['status']}',
  ),

  onTap: () {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                'Invoice Number : ${invoice['invoiceNumber']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text('Site : ${invoice['siteName']}'),
              Text('Amount : ₹${invoice['amount']}'),
              Text('Status : ${invoice['status']}'),

              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Open PDF'),
                onTap: () async {
                  if (invoice['pdfPath'] != null) {
                    await OpenFilex.open(invoice['pdfPath']);
                  }

                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share PDF'),
                onTap: () async {
                  if (invoice['pdfPath'] != null) {
                    await Share.shareXFiles([
                      XFile(invoice['pdfPath']),
                    ]);
                  }

                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete Invoice',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Delete Invoice?'),
                        content: const Text(
                          'This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    await DatabaseHelper.instance.deleteInvoice(
                      invoice['id'],
                    );

                    await loadInvoices();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  },
);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}