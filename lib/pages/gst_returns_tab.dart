import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/file_store.dart';
import '../services/pdf_opener.dart';
import '../utils/format.dart';
import '../widgets/status_pill.dart';

/// One row per month of the financial year; attach the filed GSTR-3B PDF.
class GstReturnsTab extends StatefulWidget {
  const GstReturnsTab({super.key});

  @override
  State<GstReturnsTab> createState() => _GstReturnsTabState();
}

class _GstReturnsTabState extends State<GstReturnsTab> {
  late int fyStart; // financial year starts in April of this year
  Map<String, Map<String, dynamic>> saved = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    fyStart = now.month >= 4 ? now.year : now.year - 1;
    load();
  }

  Future<void> load() async {
    final data = await DatabaseHelper.instance.getGstReturns();
    if (!mounted) return;
    setState(() {
      saved = data;
      loading = false;
    });
  }

  String _key(DateTime m) => dayKey(m).substring(0, 7);

  String get fyLabel =>
      'FY $fyStart-${((fyStart + 1) % 100).toString().padLeft(2, '0')}';

  Future<void> addOrReplace(DateTime month) async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (r == null || r.files.first.bytes == null) return;

    final key = _key(month);
    final fileName = 'GSTR-3B_$key.pdf';
    final path = await FileStore.save('gst', fileName, r.files.first.bytes!);
    await DatabaseHelper.instance.saveGstReturn(key, fileName, path);
    await load();
  }

  Future<void> open(String path) async {
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found. Replace it with a new PDF.')),
      );
      return;
    }
    await openFile(path);
  }

  Future<void> remove(DateTime month) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove GSTR-3B?'),
        content: Text('Remove the saved PDF for ${monthLabel(month)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await DatabaseHelper.instance.deleteGstReturn(_key(month));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (loading) return const Center(child: CircularProgressIndicator());

    final months = [for (var i = 0; i < 12; i++) DateTime(fyStart, 4 + i)];
    final savedCount = months.where((m) => saved.containsKey(_key(m))).length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => fyStart--),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    fyLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => fyStart++),
                ),
              ],
            ),
            Center(
              child: Text(
                '$savedCount of 12 GSTR-3B returns saved',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < months.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                    _row(months[i], scheme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(DateTime month, ColorScheme scheme) {
    final row = saved[_key(month)];
    final has = row != null;

    return InkWell(
      onTap: has ? () => open('${row['filePath']}') : () => addOrReplace(month),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              has ? Icons.picture_as_pdf : Icons.upload_file_outlined,
              color: has ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthLabel(month), style: const TextStyle(fontSize: 15)),
                  Text(
                    has
                        ? 'Saved ${fmtIso('${row['addedOn']}')}'
                        : 'Tap to add the filed PDF',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusPill(has ? 'Saved' : 'Not saved'),
            if (has)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'open') open('${row['filePath']}');
                  if (v == 'replace') addOrReplace(month);
                  if (v == 'remove') remove(month);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(value: 'replace', child: Text('Replace PDF')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
