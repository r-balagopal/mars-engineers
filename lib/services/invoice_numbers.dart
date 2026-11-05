import '../database/database_helper.dart';
import 'invoice_settings.dart';

class InvoiceNumbers {
  /// Next number = highest used with the current prefix + 1, but never below
  /// the "start number" in settings. Always read from the database, so
  /// deleting or adding invoices keeps it correct.
  static Future<String> next() async {
    final prefix = await InvoiceSettings.prefix();
    final start = await InvoiceSettings.startNumber();
    final used = await DatabaseHelper.instance.getAllInvoiceNumbers();

    var highest = 0;
    for (final n in used) {
      if (!n.startsWith(prefix)) continue;
      final v = int.tryParse(n.substring(prefix.length).trim());
      if (v != null && v > highest) highest = v;
    }

    final nextNo = highest + 1 > start ? highest + 1 : start;
    return '$prefix${nextNo.toString().padLeft(3, '0')}';
  }
}
