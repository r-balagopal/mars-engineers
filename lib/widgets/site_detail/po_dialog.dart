import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/work_order.dart';
import '../../utils/format.dart';

/// Add / edit a purchase order. Pops a [WorkOrder] on save.
class PoDialog extends StatefulWidget {
  final int siteId;
  final WorkOrder? po;

  const PoDialog({super.key, required this.siteId, this.po});

  @override
  State<PoDialog> createState() => _PoDialogState();
}

class _PoDialogState extends State<PoDialog> {
  final numberController = TextEditingController();
  final valueController = TextEditingController();
  final termsController = TextEditingController(text: '30');

  DateTime poDate = DateTime.now();
  String fileName = '';
  String filePath = '';
  String? error;

  bool get editing => widget.po != null;

  @override
  void initState() {
    super.initState();
    final po = widget.po;
    if (po != null) {
      numberController.text = po.poNumber ?? '';
      valueController.text = po.poValue?.toStringAsFixed(0) ?? '';
      termsController.text = po.paymentTermsDays.toString();
      poDate = DateTime.tryParse(po.poDate ?? '') ?? DateTime.now();
      fileName = po.fileName;
      filePath = po.filePath;
    }
  }

  @override
  void dispose() {
    numberController.dispose();
    valueController.dispose();
    termsController.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() {
      fileName = result.files.single.name;
      filePath = path;
    });
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: poDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => poDate = d);
  }

  void save() {
    final number = numberController.text.trim();
    final value = parseAmount(valueController.text);
    final terms = int.tryParse(termsController.text.trim());

    if (number.isEmpty) {
      setState(() => error = 'Enter the PO number');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => error = 'Enter the PO value');
      return;
    }
    if (terms == null || terms < 0) {
      setState(() => error = 'Enter payment terms in days');
      return;
    }

    Navigator.pop(
      context,
      WorkOrder(
        id: widget.po?.id,
        siteId: widget.siteId,
        fileName: fileName,
        filePath: filePath,
        poNumber: number,
        poValue: value,
        poDate: poDate.toIso8601String(),
        paymentTermsDays: terms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? 'Edit PO' : 'Add PO'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: numberController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'PO number'),
              ),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PO value (₹, total)',
                ),
              ),
              TextField(
                controller: termsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment terms (days)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('PO date: '),
                  TextButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(fmtDate(poDate)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(filePath.isEmpty ? 'Attach PO PDF' : 'Change PDF'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
