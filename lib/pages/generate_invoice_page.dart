import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/pdf_opener.dart';

import '../database/database_helper.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../services/file_store.dart';
import '../services/invoice_numbers.dart';
import '../services/invoice_pdf.dart';
import '../services/invoice_settings.dart';
import '../services/po_extractor.dart';
import '../utils/format.dart';

class _Item {
  final desc = TextEditingController();
  final sac = TextEditingController();
  final qty = TextEditingController();
  final unit = TextEditingController();
  final rate = TextEditingController();
  double get q => double.tryParse(qty.text.trim()) ?? 0;
  double get r => double.tryParse(rate.text.trim()) ?? 0;
  double get amount => q * r;
}

/// Upload a PO, check the extracted fields, generate the invoice PDF and save
/// it (with its PO and invoice record) under the project.
class GenerateInvoicePage extends StatefulWidget {
  final Site site;

  const GenerateInvoicePage({super.key, required this.site});

  @override
  State<GenerateInvoicePage> createState() => _GenerateInvoicePageState();
}

class _GenerateInvoicePageState extends State<GenerateInvoicePage> {
  final c = <String, TextEditingController>{
    for (final k in [
      'invoiceNo', 'poNo', 'clientName', 'clientGstin', 'clientAddress', 'gstRate'
    ])
      k: TextEditingController()
  };
  final items = <_Item>[_Item()];
  DateTime invDate = DateTime.now();
  String taxType = ''; // 'IGST' | 'CGST_SGST' | '' (not found in PO)
  bool busy = false;
  String status = '';

  List<WorkOrder> sitePos = [];
  WorkOrder? selectedPo; // saved PO used as the source
  Uint8List? poBytes; // newly uploaded PO file
  String poFileName = '';
  double? poTotal; // PO value incl. tax, as read from the PO

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rows = await DatabaseHelper.instance.getWorkOrdersBySite(widget.site.id!);
    sitePos = rows.map((e) => WorkOrder.fromMap(e)).toList();
    await _setInvoiceNo();
  }

  Future<void> _setInvoiceNo() async {
    final next = await InvoiceNumbers.next();
    if (!mounted) return;
    setState(() => c['invoiceNo']!.text = next);
  }

  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: invDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => invDate = d);
  }

  // ---------- PO reading ----------

  Future<void> uploadPo() async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (r == null || r.files.first.bytes == null) return;
    final f = r.files.first;
    await _read(f.bytes!, f.extension ?? 'pdf');
    poBytes = f.bytes;
    poFileName = f.name;
    selectedPo = null;
    setState(() {});
  }

  Future<void> useSavedPo() async {
    final withFile = sitePos.where((p) => p.hasFile).toList();
    if (withFile.isEmpty) {
      setState(() => status = 'No saved PO files in this project.');
      return;
    }
    final po = await showDialog<WorkOrder>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Use a saved PO'),
        children: [
          for (final p in withFile)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text('PO ${p.label}'),
            ),
        ],
      ),
    );
    if (po == null) return;

    final file = File(po.filePath);
    if (!await file.exists()) {
      setState(() => status = 'PO file not found: ${po.filePath}');
      return;
    }
    final bytes = await file.readAsBytes();
    final dot = po.filePath.lastIndexOf('.');
    final ext = dot >= 0 ? po.filePath.substring(dot + 1) : 'pdf';
    await _read(bytes, ext);
    selectedPo = po;
    poBytes = null;
    poFileName = '';
    setState(() {});
  }

  Future<void> _read(Uint8List bytes, String ext) async {
    final key = await InvoiceSettings.apiKey();
    if (key.isEmpty) {
      setState(() => status = 'Add your Gemini API key in Settings (gear icon) first.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Reading PO... (can take up to a minute)';
    });
    try {
      final d = await extractPo(bytes: bytes, extension: ext, apiKey: key);
      c['poNo']!.text = '${d['po_number'] ?? ''}';
      c['clientName']!.text = '${d['client_name'] ?? ''}';
      c['clientGstin']!.text = '${d['client_gstin'] ?? ''}';
      c['clientAddress']!.text = '${d['client_address'] ?? ''}';
      c['gstRate']!.text = numText(d['gst_rate']);
      final t = '${d['tax_type'] ?? ''}'.toUpperCase();
      taxType = (t == 'IGST' || t == 'CGST_SGST') ? t : '';
      items.clear();
      for (final i in (d['items'] as List? ?? [])) {
        final it = _Item();
        it.desc.text = cleanDesc('${i['description'] ?? ''}');
        it.sac.text = '${i['sac_code'] ?? ''}';
        it.unit.text = '${i['unit'] ?? ''}';
        it.qty.text = numText(i['quantity']);
        it.rate.text = numText(i['rate']);
        items.add(it);
      }
      if (items.isEmpty) items.add(_Item());

      // PO value incl. tax, taken from the PO as printed (before any edits)
      final complete = items.every((i) => i.q > 0 && i.r > 0) && gstRate > 0;
      poTotal = complete ? total : null;

      status = 'Done. Check the fields, then generate.';
    } catch (e) {
      status = '$e'.contains('Timeout')
          ? 'No response after 2 min. Check internet, then try again.'
          : 'Failed: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  // ---------- totals ----------

  double get taxable => items.fold(0.0, (s, i) => s + i.amount);
  double get gstRate => double.tryParse(c['gstRate']!.text.trim()) ?? 0;
  double get tax => ((taxable * gstRate / 100) * 100).round() / 100;
  double get total => ((taxable + tax) * 100).round() / 100;

  bool get missing =>
      items.any((i) => i.q <= 0 || i.r <= 0) ||
      c['gstRate']!.text.trim().isEmpty ||
      taxType.isEmpty;

  // ---------- generate ----------

  Future<void> generate() async {
    if (missing) {
      _snack('Fill the highlighted fields (not found in PO).');
      return;
    }
    final no = c['invoiceNo']!.text.trim();
    if (no.isEmpty) {
      _snack('Enter the invoice number.');
      return;
    }
    if (await DatabaseHelper.instance.invoiceNumberExists(no)) {
      _snack('Invoice number $no already exists. Use a different number.');
      return;
    }

    setState(() {
      busy = true;
      status = 'Generating invoice...';
    });

    try {
      final db = DatabaseHelper.instance;
      final data = InvoiceData(
        invoiceNo: no,
        date: invDate,
        poNo: c['poNo']!.text,
        clientName: c['clientName']!.text,
        clientGstin: c['clientGstin']!.text,
        clientAddress: c['clientAddress']!.text,
        items: [
          for (final i in items)
            InvoiceItem(
              desc: i.desc.text,
              sac: i.sac.text,
              unit: i.unit.text,
              qty: i.q,
              rate: i.r,
            ),
        ],
        taxType: taxType,
        gstRate: gstRate,
      );

      final pdfBytes = await buildInvoicePdf(data);
      final pdfPath = await FileStore.save(
        'invoices',
        'Invoice_$no.pdf',
        pdfBytes,
      );

      // ----- link / create the PO -----
      final poNoText = c['poNo']!.text.trim();
      final poValue = poTotal ?? data.total;
      int? poId;

      WorkOrder? po = selectedPo;
      if (po == null && poNoText.isNotEmpty) {
        for (final p in sitePos) {
          if ((p.poNumber ?? '').trim() == poNoText) po = p;
        }
      }

      if (po != null) {
        poId = po.id;
        var changed = false;
        if (po.poValue == null) {
          po.poNumber = (po.poNumber == null || po.poNumber!.isEmpty) ? poNoText : po.poNumber;
          po.poValue = poValue;
          po.poDate ??= invDate.toIso8601String();
          changed = true;
        }
        if (!po.hasFile && poBytes != null) {
          po.filePath = await FileStore.save('pos', poFileName, poBytes!);
          po.fileName = poFileName;
          changed = true;
        }
        if (changed) await db.updatePo(po);
      } else if (poNoText.isNotEmpty) {
        var path = '';
        if (poBytes != null) {
          path = await FileStore.save('pos', poFileName, poBytes!);
        }
        poId = await db.insertPo(WorkOrder(
          siteId: widget.site.id!,
          fileName: poFileName,
          filePath: path,
          poNumber: poNoText,
          poValue: poValue,
          poDate: invDate.toIso8601String(),
        ));
      }

      await db.insertInvoice(
        widget.site.id!,
        no,
        data.total,
        pdfPath,
        poId: poId,
        invoiceDate: invDate,
        dataJson: jsonEncode(data.toJson()),
      );

      await openFile(pdfPath);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Failed: $e';
        });
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---------- settings ----------

  Future<void> openSettings() async {
    final key = TextEditingController(text: await InvoiceSettings.apiKey());
    final prefix = TextEditingController(text: await InvoiceSettings.prefix());
    final start =
        TextEditingController(text: '${await InvoiceSettings.startNumber()}');
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invoice settings'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: key,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Gemini API key'),
              ),
              TextField(
                controller: prefix,
                decoration: const InputDecoration(labelText: 'Invoice prefix'),
              ),
              TextField(
                controller: start,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lowest number to use next',
                  helperText: 'Numbers continue from the last invoice automatically',
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await InvoiceSettings.save(
                apiKey: key.text,
                prefix: prefix.text,
                startNumber: start.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    await _setInvoiceNo();
  }

  // ---------- UI ----------

  InputDecoration deco(String label, {bool warn = false}) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        filled: warn,
        fillColor: warn ? Colors.orange.shade50 : null,
        enabledBorder: warn
            ? OutlineInputBorder(borderSide: BorderSide(color: Colors.orange.shade700, width: 1.5))
            : null,
        helperText: warn ? 'Not found in PO' : null,
      );

  Widget field(String k, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c[k],
          maxLines: lines,
          onChanged: (_) => setState(() {}),
          decoration: deco(label),
        ),
      );

  Widget tf(TextEditingController t, String label,
          {bool num = false, int lines = 1, bool warn = false}) =>
      TextField(
        controller: t,
        maxLines: lines,
        keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : null,
        onChanged: (_) => setState(() {}),
        decoration: deco(label, warn: warn),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New invoice · ${widget.site.name}'),
        actions: [
          IconButton(
            tooltip: 'Invoice settings',
            icon: const Icon(Icons.settings),
            onPressed: openSettings,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : uploadPo,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload PO (PDF / image)'),
                  ),
                  if (sitePos.any((p) => p.hasFile))
                    OutlinedButton.icon(
                      onPressed: busy ? null : useSavedPo,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Use a saved PO'),
                    ),
                ],
              ),
              if (busy)
                const Padding(
                    padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              if (status.isNotEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text(status)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field('invoiceNo', 'Invoice No (editable)')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        key: ValueKey(invDate),
                        initialValue: fmtDmy(invDate),
                        readOnly: true,
                        onTap: pickDate,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Today',
                            icon: const Icon(Icons.today),
                            onPressed: () =>
                                setState(() => invDate = DateTime.now()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              field('poNo', 'PO Number'),
              field('clientName', 'Client Name'),
              field('clientGstin', 'Client GSTIN'),
              field('clientAddress', 'Client Address', lines: 3),
              const Text('Work Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (var i = 0; i < items.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      tf(items[i].desc, 'Description of work', lines: 2),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: tf(items[i].sac, 'HSN/SAC')),
                        const SizedBox(width: 8),
                        Expanded(child: tf(items[i].unit, 'UOM')),
                      ]),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                            child: tf(items[i].qty, 'Qty',
                                num: true, warn: items[i].q <= 0)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: tf(items[i].rate, 'Rate',
                                num: true, warn: items[i].r <= 0)),
                      ]),
                      Row(children: [
                        Expanded(child: Text('Gross: ${money2(items[i].amount)}')),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: items.length > 1
                              ? () => setState(() => items.removeAt(i))
                              : null,
                        ),
                      ]),
                    ]),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => items.add(_Item())),
                icon: const Icon(Icons.add),
                label: const Text('Add row'),
              ),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: InputDecorator(
                    decoration: deco('Tax type', warn: taxType.isEmpty),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: taxType.isEmpty ? null : taxType,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Select'),
                        items: const [
                          DropdownMenuItem(value: 'IGST', child: Text('IGST')),
                          DropdownMenuItem(
                              value: 'CGST_SGST', child: Text('CGST + SGST')),
                        ],
                        onChanged: (v) => setState(() => taxType = v ?? ''),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: tf(c['gstRate']!, 'GST %',
                      num: true, warn: c['gstRate']!.text.trim().isEmpty),
                ),
              ]),
              const SizedBox(height: 14),
              Text('Subtotal: ${money2(taxable)}   Tax: ${money2(tax)}'),
              Text('Total: ₹ ${money2(total)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : generate,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate & save invoice'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
