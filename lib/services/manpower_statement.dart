import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/database_helper.dart';
import '../models/site.dart';
import '../models/team_member.dart';
import '../utils/format.dart';
import 'file_store.dart';

/// Asks for the statement period. Defaults to the given month.
Future<DateTimeRange?> pickStatementRange(
  BuildContext context, {
  DateTime? month,
}) {
  final m = month ?? DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    initialDateRange: DateTimeRange(
      start: DateTime(m.year, m.month, 1),
      end: DateTime(m.year, m.month + 1, 0),
    ),
    helpText: 'Statement period (from – to)',
  );
}

class _TeamRow {
  final TeamMember member;
  final int days;
  _TeamRow(this.member, this.days);
}

class _DayBlock {
  final DateTime date;
  final String description;
  final Map<String, int> byDesignation;
  _DayBlock(this.date, this.description, this.byDesignation);
  int get total => byDesignation.values.fold(0, (a, b) => a + b);
}

class StatementData {
  final String siteName;
  final DateTime from;
  final DateTime to;
  final List<_TeamRow> team;
  final List<_DayBlock> blocks;

  StatementData({
    required this.siteName,
    required this.from,
    required this.to,
    required this.team,
    required this.blocks,
  });
}

/// Reads attendance for [site] between [from] and [to].
/// Returns null when nobody has attendance in that period.
Future<StatementData?> loadStatementData({
  required Site site,
  required DateTime from,
  required DateTime to,
}) async {
  final db = DatabaseHelper.instance;
  final fromKey = dayKey(from);
  final toKey = dayKey(to);

  final memberRows = await db.getTeamMembersBySite(site.id!);
  final members = memberRows.map((e) => TeamMember.fromMap(e)).toList();
  final byId = {for (final m in members) m.id!: m};

  final att = await db.getAttendanceInRange(site.id!, fromKey, toKey);
  final logs = await db.getWorkLogs(site.id!, fromKey, toKey);

  // date -> member ids present
  final presentByDate = <String, List<int>>{};
  final daysByMember = <int, int>{};
  for (final r in att) {
    final id = r['memberId'] as int;
    if (!byId.containsKey(id)) continue;
    presentByDate.putIfAbsent('${r['date']}', () => []).add(id);
    daysByMember[id] = (daysByMember[id] ?? 0) + 1;
  }
  if (presentByDate.isEmpty) return null;

  // team table: arrival date, then name
  final team = [
    for (final e in daysByMember.entries) _TeamRow(byId[e.key]!, e.value),
  ]..sort((a, b) {
      final c = a.member.startDate.compareTo(b.member.startDate);
      return c != 0
          ? c
          : a.member.name.toLowerCase().compareTo(b.member.name.toLowerCase());
    });

  // day blocks
  final dates = presentByDate.keys.toList()..sort();
  final blocks = <_DayBlock>[];
  for (final k in dates) {
    final counts = <String, int>{};
    for (final id in presentByDate[k]!) {
      final d = byId[id]!.designation.trim();
      final label = d.isEmpty ? 'Worker' : d;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    blocks.add(_DayBlock(DateTime.parse(k), logs[k] ?? '', sorted));
  }

  return StatementData(
    siteName: site.name,
    from: from,
    to: to,
    team: team,
    blocks: blocks,
  );
}

/// Builds the statement PDF for [site], saves it in the app folder and
/// returns its path (null when there is no attendance in the period).
Future<String?> createManpowerStatement({
  required Site site,
  required DateTime from,
  required DateTime to,
}) async {
  final data = await loadStatementData(site: site, from: from, to: to);
  if (data == null) return null;

  final doc = pw.Document();
  await addStatementPages(doc, data);
  final bytes = await doc.save();

  final name = 'Manpower_${site.name}_${dayKey(from)}_to_${dayKey(to)}.pdf'
      .replaceAll(' ', '_');
  return FileStore.save('statements', name, bytes);
}

/// Adds the statement pages (page 1 with letterhead, then the daily list)
/// to [doc], so a package can combine documents.
Future<void> addStatementPages(pw.Document doc, StatementData data) async {
  final siteName = data.siteName;
  final from = data.from;
  final to = data.to;
  final team = data.team;
  final blocks = data.blocks;

  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Bold.ttf'));
  final letterhead = pw.MemoryImage(
    (await rootBundle.load('assets/letterhead.png')).buffer.asUint8List(),
  );

  const grey = PdfColor.fromInt(0xffE9ECF1);

  pw.Widget t(String s, {double size = 11, bool b = false, pw.TextAlign? align}) =>
      pw.Text(
        s,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );

  pw.Widget cell(String s, {bool b = false, bool center = false, PdfColor? bg}) =>
      pw.Container(
        color: bg,
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: t(s, b: b, size: 10.5),
      );

  final border = pw.TableBorder.all(width: 0.8);
  final totalDays = team.fold<int>(0, (s, r) => s + r.days);

  // ----- team table: Arrival first, Leaving last -----
  final teamRows = <pw.TableRow>[
    pw.TableRow(children: [
      cell('Arrival', b: true, bg: grey),
      cell('Name', b: true, bg: grey),
      cell('Designation', b: true, bg: grey),
      cell('Total days', b: true, center: true, bg: grey),
      cell('Leaving', b: true, bg: grey),
    ]),
    for (final r in team)
      pw.TableRow(children: [
        cell(fmtIso(r.member.startDate)),
        cell(r.member.name),
        cell(r.member.designation),
        cell('${r.days}', center: true),
        cell(
          (r.member.endDate == null || r.member.endDate!.trim().isEmpty)
              ? 'Working'
              : fmtIso(r.member.endDate),
        ),
      ]),
  ];

  // ----- one block per working day -----
  pw.Widget dayBlock(_DayBlock d) {
    final designations = d.byDesignation.entries
        .map((e) => '${e.key} – ${e.value}')
        .join('      ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            color: grey,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                t('${fmtDmy(d.date)}  ·  ${weekdayNames[d.date.weekday - 1]}',
                    b: true, size: 10.5),
                t('Total manpower: ${d.total}', b: true, size: 10.5),
              ],
            ),
          ),
          if (d.description.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: t('Work description: ${d.description}', size: 10.5),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: t(designations, size: 10.5),
          ),
        ],
      ),
    );
  }

  pw.Widget signLine(String label) => pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(right: 18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 3),
              t(label, size: 10),
            ],
          ),
        ),
      );

  doc.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: reg, bold: bold),
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(44, 36, 44, 40),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: t('Page ${ctx.pageNumber} of ${ctx.pagesCount}', size: 9),
    ),
    build: (ctx) => [
      // ===== page 1 =====
      pw.Image(letterhead, width: 507),
      pw.SizedBox(height: 18),
      pw.Center(
        child: t('MANPOWER DETAILS FOR ${siteName.toUpperCase()} SITE',
            b: true, size: 15, align: pw.TextAlign.center),
      ),
      pw.SizedBox(height: 12),
      t('Period: ${fmtDmy(from)} to ${fmtDmy(to)}', size: 11.5),
      pw.SizedBox(height: 3),
      t('Total working days: ${blocks.length}', size: 11.5, b: true),
      pw.SizedBox(height: 14),
      pw.Table(
        border: border,
        columnWidths: {
          0: const pw.FixedColumnWidth(70),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FixedColumnWidth(62),
          4: const pw.FixedColumnWidth(70),
        },
        children: teamRows,
      ),
      pw.SizedBox(height: 8),
      t('Total man-days: $totalDays', b: true, size: 11),

      // ===== page 2 onwards =====
      pw.NewPage(),
      t('Attendance details', b: true, size: 13),
      pw.SizedBox(height: 10),
      for (final d in blocks) dayBlock(d),
      pw.SizedBox(height: 24),
      pw.Wrap(children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            t('Attested by (Site In-charge):', b: true, size: 11),
            pw.SizedBox(height: 40),
            pw.Row(children: [
              signLine('Name'),
              signLine('Signature'),
              signLine('Date'),
            ]),
          ],
        ),
      ]),
    ],
  ));
}
