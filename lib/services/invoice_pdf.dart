import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/format.dart';

// ---------- fixed company details (from template) ----------
const kAddress = 'PUTHENPARAMBU MADAM, THALAVADY P.O., ALAPPUZHA, KERALA, INDIA - 689572';
const kContact = 'Email: rrmarsengineers@gmail.com, Phone: 8281654045';
const kGstin = 'GSTIN: 32AFQPA4331K1ZN';

class InvoiceItem {
  String desc;
  String sac;
  String unit;
  double qty;
  double rate;

  InvoiceItem({
    this.desc = '',
    this.sac = '',
    this.unit = '',
    this.qty = 0,
    this.rate = 0,
  });

  double get amount => qty * rate;

  Map<String, dynamic> toJson() =>
      {'desc': desc, 'sac': sac, 'unit': unit, 'qty': qty, 'rate': rate};

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        desc: '${j['desc'] ?? ''}',
        sac: '${j['sac'] ?? ''}',
        unit: '${j['unit'] ?? ''}',
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
      );
}

class InvoiceData {
  final String invoiceNo;
  final DateTime date;
  final String poNo;
  final String clientName;
  final String clientGstin;
  final String clientAddress;
  final List<InvoiceItem> items;
  final String taxType; // 'IGST' | 'CGST_SGST'
  final double gstRate;

  InvoiceData({
    required this.invoiceNo,
    required this.date,
    required this.poNo,
    required this.clientName,
    required this.clientGstin,
    required this.clientAddress,
    required this.items,
    required this.taxType,
    required this.gstRate,
  });

  double get taxable => items.fold(0.0, (s, i) => s + i.amount);
  double get tax => ((taxable * gstRate / 100) * 100).round() / 100;
  double get total => ((taxable + tax) * 100).round() / 100;

  Map<String, dynamic> toJson() => {
        'invoiceNo': invoiceNo,
        'date': date.toIso8601String(),
        'poNo': poNo,
        'clientName': clientName,
        'clientGstin': clientGstin,
        'clientAddress': clientAddress,
        'items': [for (final i in items) i.toJson()],
        'taxType': taxType,
        'gstRate': gstRate,
      };

  factory InvoiceData.fromJson(Map<String, dynamic> j) => InvoiceData(
        invoiceNo: '${j['invoiceNo'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}') ?? DateTime.now(),
        poNo: '${j['poNo'] ?? ''}',
        clientName: '${j['clientName'] ?? ''}',
        clientGstin: '${j['clientGstin'] ?? ''}',
        clientAddress: '${j['clientAddress'] ?? ''}',
        items: [
          for (final i in (j['items'] as List? ?? []))
            InvoiceItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        taxType: '${j['taxType'] ?? 'IGST'}',
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
      );
}

String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

Future<Uint8List> buildInvoicePdf(InvoiceData d) async {
  final doc = pw.Document();
  await addInvoicePages(doc, d);
  return doc.save();
}

/// Adds the invoice page(s) to [doc] (so a package can combine documents).
Future<void> addInvoicePages(pw.Document doc, InvoiceData d) async {
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Bold.ttf'));
  final sig = pw.MemoryImage((await rootBundle.load('assets/signature.png')).buffer.asUint8List());

  const navy = PdfColor.fromInt(0xff1F3864);
  const maroon = PdfColor.fromInt(0xff8B2323);
  const blue = PdfColor.fromInt(0xff4F81BD);

  pw.Widget t(String s,
          {double size = 11, bool b = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Text(s,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: size,
              color: color,
              fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal));

  pw.Widget cell(String s,
          {bool b = false, pw.Alignment al = pw.Alignment.centerLeft, double minH = 0}) =>
      pw.Container(
        alignment: al,
        constraints: minH > 0 ? pw.BoxConstraints(minHeight: minH) : null,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: t(s, b: b, size: 10.5),
      );

  pw.Widget section(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6), child: t(s, b: true, size: 11.5));

  final border = pw.TableBorder.all(width: 0.8);
  final items = d.items;

  // work rows
  final workRows = <pw.TableRow>[
    pw.TableRow(children: [
      cell('Sr. No.', b: true),
      cell('HSN/SAC', b: true),
      cell('Description of Work', b: true),
      cell('UOM', b: true),
      cell('Qty', b: true),
      cell('Rate (₹)', b: true),
      cell('Gross Amt', b: true),
    ]),
    for (var i = 0; i < items.length; i++)
      pw.TableRow(children: [
        cell('${i + 1}', minH: 24),
        cell(items[i].sac.trim()),
        cell(items[i].desc.trim()),
        cell(items[i].unit.trim()),
        cell(_fmt(items[i].qty)),
        cell(money2(items[i].rate)),
        cell(money2(items[i].amount)),
      ]),
  ];

  // summary rows
  final tax = d.tax;
  final rt = _fmt(d.gstRate);
  final summary = <List<String>>[
    ['Subtotal', '₹ ${money2(d.taxable)}'],
  ];
  if (d.taxType == 'IGST') {
    summary.add(['IGST @ $rt%', '₹ ${money2(tax)}']);
  } else {
    final cgst = (tax / 2 * 100).round() / 100;
    final sgst = ((tax - cgst) * 100).round() / 100;
    summary.add(['CGST @ ${_fmt(d.gstRate / 2)}%', '₹ ${money2(cgst)}']);
    summary.add(['SGST @ ${_fmt(d.gstRate / 2)}%', '₹ ${money2(sgst)}']);
  }
  summary.add(['Total Amount', '₹ ${money2(d.total)}']);

  doc.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: reg, bold: bold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(44, 36, 44, 36),
    build: (ctx) => [
      pw.Center(child: t('TAX INVOICE', size: 20)),
      pw.SizedBox(height: 4),
      pw.Container(height: 3, color: maroon),
      pw.SizedBox(height: 1.5),
      pw.Container(height: 0.8, color: maroon),
      pw.SizedBox(height: 14),
      pw.Center(child: t('MARS ENGINEERS', size: 32, color: navy)),
      pw.SizedBox(height: 4),
      pw.Container(height: 1, color: blue),
      pw.SizedBox(height: 10),
      pw.Center(child: t(kAddress, size: 10.5)),
      pw.Center(child: t(kContact, size: 10.5)),
      pw.Center(child: t(kGstin, size: 10.5)),
      section('Invoice Details:'),
      pw.Table(
        border: border,
        columnWidths: {
          0: const pw.FlexColumnWidth(1.1),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1.1),
          3: const pw.FlexColumnWidth(1.7),
        },
        children: [
          pw.TableRow(children: [
            cell('Invoice No.'),
            cell(d.invoiceNo.trim()),
            cell('Date'),
            cell(fmtDmy(d.date)),
          ]),
          pw.TableRow(children: [
            cell('PO Number'),
            cell(d.poNo.trim()),
            cell('Client GSTIN'),
            cell(d.clientGstin.trim()),
          ]),
        ],
      ),
      section('Client Details:'),
      pw.Table(
        border: border,
        columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(3.2)},
        children: [
          pw.TableRow(children: [cell('Client Name'), cell(d.clientName.trim())]),
          pw.TableRow(children: [
            cell('Client Address', minH: 44),
            cell(d.clientAddress.trim()),
          ]),
        ],
      ),
      section('Work Details:'),
      pw.Table(
        border: border,
        columnWidths: {
          0: const pw.FixedColumnWidth(36),
          1: const pw.FixedColumnWidth(58),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FixedColumnWidth(38),
          4: const pw.FixedColumnWidth(40),
          5: const pw.FixedColumnWidth(62),
          6: const pw.FixedColumnWidth(74),
        },
        children: workRows,
      ),
      pw.SizedBox(height: 14),
      pw.Wrap(children: [
        section('Total Summary:'),
        pw.Table(
          border: border,
          columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1)},
          children: [
            for (final r in summary)
              pw.TableRow(children: [
                cell(r[0], b: r[0] == 'Total Amount'),
                cell(r[1], b: r[0] == 'Total Amount'),
              ]),
          ],
        ),
      ]),
      pw.SizedBox(height: 14),
      pw.Text('Amount in Words: ${_words(d.total)}',
          style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 18),
      pw.Image(sig, width: 190),
    ],
  ));
}

String _words(double amt) {
  final all = (amt * 100).round();
  final rupees = all ~/ 100, paise = all % 100;
  var s = '${_inWords(rupees)} Rupees';
  if (paise > 0) s += ' and ${_inWords(paise)} Paise';
  return '$s Only';
}

String _inWords(int n) {
  const a = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'];
  const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String two(int x) => x < 20 ? a[x] : b[x ~/ 10] + (x % 10 > 0 ? ' ${a[x % 10]}' : '');
  String three(int x) => x >= 100
      ? '${a[x ~/ 100]} Hundred${x % 100 > 0 ? ' ${two(x % 100)}' : ''}'
      : two(x);
  if (n == 0) return 'Zero';
  final p = <String>[];
  final cr = n ~/ 10000000; n %= 10000000;
  final lk = n ~/ 100000; n %= 100000;
  final th = n ~/ 1000; n %= 1000;
  if (cr > 0) p.add('${three(cr)} Crore');
  if (lk > 0) p.add('${two(lk)} Lakh');
  if (th > 0) p.add('${two(th)} Thousand');
  if (n > 0) p.add(three(n));
  return p.join(' ');
}
