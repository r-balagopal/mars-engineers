import 'package:pdf/widgets.dart' as pw;

import '../models/site.dart';
import 'file_store.dart';
import 'invoice_pdf.dart';
import 'manpower_statement.dart';

class PackageResult {
  final String path;
  final bool statementIncluded;

  PackageResult(this.path, this.statementIncluded);
}

/// One PDF: the invoice(s) first, then the attendance statement for the
/// period (when [from]/[to] are given and attendance exists).
Future<PackageResult> buildPackage({
  required Site site,
  required List<InvoiceData> invoices,
  DateTime? from,
  DateTime? to,
}) async {
  final doc = pw.Document();

  for (final inv in invoices) {
    await addInvoicePages(doc, inv);
  }

  var included = false;
  if (from != null && to != null) {
    final data = await loadStatementData(site: site, from: from, to: to);
    if (data != null) {
      await addStatementPages(doc, data);
      included = true;
    }
  }

  final bytes = await doc.save();
  final first = invoices.first.invoiceNo;
  final more = invoices.length > 1 ? '_plus${invoices.length - 1}' : '';
  final name = 'Package_${site.name}_$first$more.pdf'.replaceAll(' ', '_');

  final path = await FileStore.save('packages', name, bytes);
  return PackageResult(path, included);
}
