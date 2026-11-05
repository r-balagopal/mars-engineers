import 'dart:convert';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/site.dart';
import '../services/invoice_pdf.dart';
import '../services/package_builder.dart';
import '../services/pdf_opener.dart';
import '../utils/format.dart';

/// Bundles invoice(s) and the attendance statement into one PDF.
class PackagePage extends StatefulWidget {
  final Site? site;

  const PackagePage({super.key, this.site});

  @override
  State<PackagePage> createState() => _PackagePageState();
}

class _PackagePageState extends State<PackagePage> {
  List<Site> sites = [];
  int? siteId;
  List<Invoice> invoices = [];
  final Set<int> selected = {};

  bool includeStatement = true;
  DateTimeRange? range;
  bool rangeCustom = false;
  bool loading = true;
  bool busy = false;

  Site? get site {
    for (final s in sites) {
      if (s.id == siteId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rows = await DatabaseHelper.instance.getSites();
    final list = rows.map((e) => Site.fromMap(e)).toList()
      ..sort((a, b) {
        if (a.status != b.status) return a.status == 'Active' ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    sites = list;
    if (widget.site != null) {
      siteId = widget.site!.id;
    } else if (list.length == 1) {
      siteId = list.first.id;
    }
    if (siteId != null) await _loadInvoices();
    if (mounted) setState(() => loading = false);
  }

  bool _hasData(Invoice i) => i.dataJson != null && i.dataJson!.isNotEmpty;

  Future<void> _loadInvoices() async {
    final rows = await DatabaseHelper.instance.getInvoicesBySite(siteId!);
    invoices = rows.map((e) => Invoice.fromMap(e)).toList();

    selected.clear();
    final firstWithData = invoices.where(_hasData).toList();
    if (firstWithData.isNotEmpty) selected.add(firstWithData.first.id!);
    rangeCustom = false;
    _defaultRange();
  }

  /// Statement period defaults to the month of the earliest selected invoice.
  void _defaultRange() {
    if (rangeCustom) return;
    final dates = invoices
        .where((i) => selected.contains(i.id))
        .map((i) => DateTime.tryParse(i.invoiceDate ?? ''))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final m = dates.isEmpty ? DateTime.now() : dates.first;
    range = DateTimeRange(
      start: DateTime(m.year, m.month, 1),
      end: DateTime(m.year, m.month + 1, 0),
    );
  }

  Future<void> pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: range,
      helpText: 'Statement period (from – to)',
    );
    if (r != null) {
      setState(() {
        range = r;
        rangeCustom = true;
      });
    }
  }

  Future<void> create() async {
    final s = site;
    if (s == null || selected.isEmpty) return;

    setState(() => busy = true);
    try {
      final chosen = invoices.where((i) => selected.contains(i.id)).toList()
        ..sort((a, b) => (a.invoiceDate ?? '').compareTo(b.invoiceDate ?? ''));

      final data = [
        for (final i in chosen)
          InvoiceData.fromJson(
            Map<String, dynamic>.from(jsonDecode(i.dataJson!) as Map),
          ),
      ];

      final result = await buildPackage(
        site: s,
        invoices: data,
        from: includeStatement ? range?.start : null,
        to: includeStatement ? range?.end : null,
      );

      if (!mounted) return;
      await openFile(result.path);

      if (includeStatement && !result.statementIncluded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No attendance marked for that period, so the package has the invoice only.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create the package: $e')),
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create package')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'One PDF with the invoice first, then the attendance statement.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (widget.site == null)
                      DropdownButtonFormField<int>(
                        initialValue: siteId,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final s in sites)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) async {
                          siteId = v;
                          await _loadInvoices();
                          if (mounted) setState(() {});
                        },
                      )
                    else
                      Text(widget.site!.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (siteId != null) ...[
                      Text('Invoices',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      if (invoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No invoices in this project yet.'),
                        ),
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            for (final i in invoices)
                              CheckboxListTile(
                                value: selected.contains(i.id),
                                onChanged: _hasData(i)
                                    ? (v) => setState(() {
                                          v == true
                                              ? selected.add(i.id!)
                                              : selected.remove(i.id);
                                          _defaultRange();
                                        })
                                    : null,
                                title: Text(i.invoiceNumber),
                                subtitle: Text(
                                  _hasData(i)
                                      ? '${fmtIso(i.invoiceDate)} · ${inrFull(i.amount)} · ${i.status}'
                                      : 'Entered manually or made before packages, so it can\'t be bundled',
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeStatement,
                        onChanged: (v) => setState(() => includeStatement = v),
                        title: const Text('Include attendance statement'),
                        subtitle: const Text(
                          'Left out automatically if no attendance is marked in the period',
                        ),
                      ),
                      if (includeStatement && range != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: pickRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              '${fmtDmy(range!.start)} to ${fmtDmy(range!.end)}',
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed:
                            (busy || selected.isEmpty) ? null : create,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(busy ? 'Creating...' : 'Create package'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
