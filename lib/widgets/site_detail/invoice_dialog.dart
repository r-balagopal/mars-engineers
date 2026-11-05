import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/pdf_opener.dart';

import '../../database/database_helper.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../models/work_order.dart';
import '../../utils/format.dart';
import '../status_pill.dart';

/// Add or edit an invoice. In edit mode it also lists payments and lets you
/// record new ones. Calls [onChanged] after anything is saved so the page
/// behind can reload.
class InvoiceDialog extends StatefulWidget {
  final int siteId;
  final List<WorkOrder> pos;
  final Invoice? invoice;
  final Future<void> Function() onChanged;

  const InvoiceDialog({
    super.key,
    required this.siteId,
    required this.pos,
    required this.onChanged,
    this.invoice,
  });

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  final numberController = TextEditingController();
  final amountController = TextEditingController();
  final payAmountController = TextEditingController();
  final payRefController = TextEditingController();

  int? poId;
  String? pdfPath;
  String? error;
  DateTime payDate = DateTime.now();

  List<Payment> payments = [];
  double paid = 0;
  String status = 'Pending';

  bool get editing => widget.invoice != null;

  double get amount => parseAmount(amountController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      numberController.text = inv.invoiceNumber;
      amountController.text = inv.amount.toStringAsFixed(0);
      poId = inv.poId;
      pdfPath = inv.pdfPath;
      status = inv.status;
      loadPayments();
    } else if (widget.pos.length == 1) {
      poId = widget.pos.first.id;
    }
  }

  @override
  void dispose() {
    numberController.dispose();
    amountController.dispose();
    payAmountController.dispose();
    payRefController.dispose();
    super.dispose();
  }

  Future<void> loadPayments() async {
    final rows =
        await DatabaseHelper.instance.getPaymentsByInvoice(widget.invoice!.id!);
    final list = rows.map((e) => Payment.fromMap(e)).toList();
    final total = list.fold<double>(0, (s, p) => s + p.amount);
    final balance = (amount - total).clamp(0, double.infinity);

    if (!mounted) return;
    setState(() {
      payments = list;
      paid = total;
      payAmountController.text = balance > 0 ? balance.toStringAsFixed(0) : '';
      status = total <= 0
          ? 'Pending'
          : (total + 0.5 >= amount ? 'Paid' : 'Part paid');
    });
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => pdfPath = path);
  }

  Future<void> pickPayDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: payDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => payDate = d);
  }

  Future<void> save() async {
    final number = numberController.text.trim();
    final amt = parseAmount(amountController.text);

    if (number.isEmpty) {
      setState(() => error = 'Enter the invoice number');
      return;
    }
    if (amt == null || amt <= 0) {
      setState(() => error = 'Enter the invoice amount');
      return;
    }

    final db = DatabaseHelper.instance;
    if (editing) {
      await db.updateInvoice(
        widget.invoice!.id!,
        number,
        amt,
        poId: poId,
        pdfPath: pdfPath,
      );
    } else {
      await db.insertInvoice(widget.siteId, number, amt, pdfPath, poId: poId);
    }

    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> addPayment() async {
    final amt = parseAmount(payAmountController.text);
    if (amt == null || amt <= 0) {
      setState(() => error = 'Enter the payment amount');
      return;
    }
    error = null;

    final ref = payRefController.text.trim();
    await DatabaseHelper.instance.insertPayment(
      widget.invoice!.id!,
      amt,
      payDate.toIso8601String(),
      ref.isEmpty ? null : ref,
    );
    payRefController.clear();
    await loadPayments();
    await widget.onChanged();
  }

  Future<void> removePayment(Payment p) async {
    await DatabaseHelper.instance.deletePayment(p.id!, p.invoiceId);
    await loadPayments();
    await widget.onChanged();
  }

  Future<void> confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Delete "${widget.invoice!.invoiceNumber}" and its payments? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await DatabaseHelper.instance.deleteInvoice(widget.invoice!.id!);
    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance = (amount - paid).clamp(0, double.infinity).toDouble();

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(editing ? 'Invoice' : 'Add invoice')),
          if (editing) StatusPill(status),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: numberController,
                autofocus: !editing,
                decoration: const InputDecoration(labelText: 'Invoice number'),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Invoice amount (₹, incl. GST)',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: poId,
                decoration: const InputDecoration(labelText: 'Against PO'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No PO'),
                  ),
                  for (final po in widget.pos)
                    DropdownMenuItem<int?>(
                      value: po.id,
                      child: Text('PO ${po.label}'),
                    ),
                ],
                onChanged: (v) => setState(() => poId = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: pickPdf,
                    icon: const Icon(Icons.attach_file),
                    label: Text(pdfPath == null ? 'Attach PDF' : 'Change PDF'),
                  ),
                  if (pdfPath != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Open PDF',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => openFile(pdfPath!),
                    ),
                  ],
                ],
              ),
              if (editing) ...[
                const SizedBox(height: 18),
                Divider(color: scheme.outlineVariant),
                Text(
                  'Payments · paid ${inrFull(paid)} · balance ${inrFull(balance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (payments.isEmpty)
                  Text('No payments recorded',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                for (final p in payments)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(inrFull(p.amount)),
                    subtitle: Text(
                      '${fmtIso(p.paidDate)}'
                      '${p.reference == null ? '' : ' · ${p.reference}'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove payment',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => removePayment(p),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: payAmountController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Amount received'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: pickPayDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(fmtDate(payDate)),
                    ),
                  ],
                ),
                TextField(
                  controller: payRefController,
                  decoration: const InputDecoration(
                    labelText: 'Reference (UTR / cheque no.), optional',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: addPayment,
                    icon: const Icon(Icons.add),
                    label: const Text('Record payment'),
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: TextStyle(color: scheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: confirmDelete,
            child: Text('Delete', style: TextStyle(color: scheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(editing ? 'Close' : 'Cancel'),
        ),
        FilledButton(
          onPressed: save,
          child: Text(editing ? 'Save changes' : 'Add'),
        ),
      ],
    );
  }
}
