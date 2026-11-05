import 'package:flutter/material.dart';
import '../services/pdf_opener.dart';

import '../database/database_helper.dart';
import '../models/site.dart';
import '../models/team_member.dart';
import '../services/manpower_statement.dart';
import '../utils/format.dart';

/// Month grid: workers down the side, days across. Tap a cell to toggle
/// present. Tap a day number for the work description / mark whole day.
class AttendancePage extends StatefulWidget {
  final Site site;

  const AttendancePage({super.key, required this.site});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const double nameW = 210;
  static const double dayW = 40;
  static const double headH = 52;
  static const double rowH = 46;
  static const double footH = 38;

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<TeamMember> members = [];
  final Set<String> present = {}; // '<memberId>|<yyyy-MM-dd>'
  Map<String, String> logs = {}; // yyyy-MM-dd -> work description
  bool loading = true;

  int get daysInMonth => DateUtils.getDaysInMonth(month.year, month.month);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    final id = widget.site.id!;
    final from = dayKey(DateTime(month.year, month.month, 1));
    final to = dayKey(DateTime(month.year, month.month, daysInMonth));

    final memberRows = await db.getTeamMembersBySite(id);
    final att = await db.getAttendanceInRange(id, from, to);
    final workLogs = await db.getWorkLogs(id, from, to);

    final list = memberRows.map((e) => TeamMember.fromMap(e)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    setState(() {
      members = list;
      present
        ..clear()
        ..addAll(att.map((r) => '${r['memberId']}|${r['date']}'));
      logs = workLogs;
      loading = false;
    });
  }

  void changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      loading = true;
    });
    load();
  }

  DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A worker can only be marked between their arrival and leaving dates.
  bool eligible(TeamMember m, DateTime date) {
    final start = DateTime.tryParse(m.startDate);
    if (start != null && date.isBefore(_only(start))) return false;
    final endText = m.endDate;
    if (endText != null && endText.trim().isNotEmpty) {
      final end = DateTime.tryParse(endText);
      if (end != null && date.isAfter(_only(end))) return false;
    }
    return true;
  }

  String key(TeamMember m, DateTime d) => '${m.id}|${dayKey(d)}';

  int totalFor(TeamMember m) {
    final prefix = '${m.id}|${month.year}-${month.month.toString().padLeft(2, '0')}';
    return present.where((k) => k.startsWith(prefix)).length;
  }

  int countOn(DateTime d) => members.where((m) => present.contains(key(m, d))).length;

  Future<void> toggle(TeamMember m, DateTime d) async {
    final k = key(m, d);
    final now = !present.contains(k);
    setState(() => now ? present.add(k) : present.remove(k));
    await DatabaseHelper.instance.setAttendance(m.id!, widget.site.id!, dayKey(d), now);
  }

  // ---------- day dialog ----------

  Future<void> openDay(DateTime d) async {
    final ctl = TextEditingController(text: logs[dayKey(d)] ?? '');
    final db = DatabaseHelper.instance;
    final siteId = widget.site.id!;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${fmtDmy(d)} · ${weekdayNames[d.weekday - 1]}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Work description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await db.clearDayAttendance(siteId, dayKey(d));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Clear day'),
          ),
          TextButton(
            onPressed: () async {
              await db.fillAttendance(siteId, [
                for (final m in members)
                  if (eligible(m, d)) (m.id!, dayKey(d)),
              ]);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('All present'),
          ),
          FilledButton(
            onPressed: () async {
              await db.setWorkLog(siteId, dayKey(d), ctl.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save note'),
          ),
        ],
      ),
    );
    ctl.dispose();
    await load();
  }

  // ---------- fill a range as present ----------

  Future<void> fillRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(month.year, month.month, 1),
        end: DateTime(month.year, month.month, daysInMonth),
      ),
      helpText: 'Mark everyone present from – to',
    );
    if (range == null || !mounted) return;

    var skipSundays = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Mark everyone present?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${fmtDmy(range.start)} to ${fmtDmy(range.end)}\n'
                  'Only between each worker\'s arrival and leaving dates. '
                  'Then tap the absences to untick them.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: skipSundays,
                onChanged: (v) => setLocal(() => skipSundays = v ?? true),
                title: const Text('Skip Sundays'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark present'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final pairs = <(int, String)>[];
    for (var d = _only(range.start);
        !d.isAfter(range.end);
        d = d.add(const Duration(days: 1))) {
      if (skipSundays && d.weekday == DateTime.sunday) continue;
      for (final m in members) {
        if (eligible(m, d)) pairs.add((m.id!, dayKey(d)));
      }
    }
    await DatabaseHelper.instance.fillAttendance(widget.site.id!, pairs);
    await load();
  }

  // ---------- statement ----------

  Future<void> makeStatement() async {
    final range = await pickStatementRange(context, month: month);
    if (range == null) return;

    final path = await createManpowerStatement(
      site: widget.site,
      from: range.start,
      to: range.end,
    );
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance marked in that period.')),
      );
      return;
    }
    await openFile(path);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance · ${widget.site.name}'),
        actions: [
          TextButton.icon(
            onPressed: members.isEmpty ? null : fillRange,
            icon: const Icon(Icons.done_all),
            label: const Text('Fill present'),
          ),
          TextButton.icon(
            onPressed: makeStatement,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Statement'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => changeMonth(-1),
                ),
                SizedBox(
                  width: 170,
                  child: Text(
                    monthLabel(month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => changeMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : members.isEmpty
                    ? const Center(
                        child: Text(
                          'Add team members in the Manpower tab first',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : _grid(scheme),
          ),
        ],
      ),
    );
  }

  Widget _grid(ColorScheme scheme) {
    final days = [
      for (var i = 1; i <= daysInMonth; i++) DateTime(month.year, month.month, i)
    ];
    final line = BorderSide(color: scheme.outlineVariant, width: 0.6);

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- left: names + totals -----
          SizedBox(
            width: nameW,
            child: Column(
              children: [
                Container(
                  height: headH,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    border: Border(bottom: line),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                          child: Text('Worker',
                              style: TextStyle(fontWeight: FontWeight.w600))),
                      Text('Days',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                for (final m in members)
                  Container(
                    height: rowH,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: line)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14)),
                              Text(m.designation,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('${totalFor(m)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                Container(
                  height: footH,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Manpower per day',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),

          // ----- right: day columns -----
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final d in days)
                        InkWell(
                          onTap: () => openDay(d),
                          child: Container(
                            width: dayW,
                            height: headH,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              border: Border(bottom: line, left: line),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: d.weekday == DateTime.sunday
                                        ? scheme.error
                                        : null,
                                  ),
                                ),
                                Text(
                                  weekdayNames[d.weekday - 1][0],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant),
                                ),
                                if (logs.containsKey(dayKey(d)))
                                  Icon(Icons.circle,
                                      size: 6, color: scheme.primary),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final m in members)
                    Row(
                      children: [
                        for (final d in days) _cell(m, d, scheme, line),
                      ],
                    ),
                  Row(
                    children: [
                      for (final d in days)
                        SizedBox(
                          width: dayW,
                          height: footH,
                          child: Center(
                            child: Text(
                              countOn(d) > 0 ? '${countOn(d)}' : '',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(TeamMember m, DateTime d, ColorScheme scheme, BorderSide line) {
    final ok = eligible(m, d);
    final on = present.contains(key(m, d));

    return InkWell(
      onTap: ok ? () => toggle(m, d) : null,
      child: Container(
        width: dayW,
        height: rowH,
        decoration: BoxDecoration(
          color: !ok
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : on
                  ? const Color(0xFFDDF3E1)
                  : null,
          border: Border(bottom: line, left: line),
        ),
        child: on
            ? const Icon(Icons.check, size: 18, color: Color(0xFF1B6B2F))
            : null,
      ),
    );
  }
}
