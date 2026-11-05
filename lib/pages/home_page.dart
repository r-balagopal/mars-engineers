import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/site.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'attendance_page.dart';
import 'generate_invoice_page.dart';
import 'package_page.dart';
import 'site_detail_page.dart';

class _Alert {
  final int siteId;
  final IconData icon;
  final String title;
  final String subtitle;
  final String pill;
  final Color pillBg;
  final Color pillFg;
  final int priority; // higher = shown first

  _Alert({
    required this.siteId,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.pillBg,
    required this.pillFg,
    required this.priority,
  });
}

class _Project {
  final int id;
  final String name;
  final double poValue;
  final double billed;
  final double due;

  _Project(this.id, this.name, this.poValue, this.billed, this.due);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  double outstanding = 0;
  double receivedMonth = 0;
  double billedMonth = 0;
  final List<_Alert> alerts = [];
  final List<_Project> projects = [];

  static const _red = Color(0xFFFCE4E4);
  static const _redText = Color(0xFFB3261E);
  static const _amber = Color(0xFFFFF0CC);
  static const _amberText = Color(0xFF8A5A00);

  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final from = dayKey(monthStart);
    final to = dayKey(nextMonth);

    final out = await db.getOutstandingAmount();
    final received = await db.getReceivedBetween(from, to);
    final billed = await db.getBilledBetween(from, to);
    final summaries = await db.getActiveProjectSummaries();
    final pending = await db.getPendingInvoicesWithSite();
    final awaiting = await db.getPosAwaitingInvoice();
    final poStatus = await db.getPoBillingStatus();

    final list = <_Alert>[];

    // ----- overdue payments -----
    for (final r in pending) {
      final date = DateTime.tryParse('${r['invoiceDate'] ?? ''}');
      if (date == null) continue;
      final terms = (r['termsDays'] as num).toInt();
      final overdueDays = now.difference(date.add(Duration(days: terms))).inDays;
      if (overdueDays >= 0) {
        list.add(_Alert(
          siteId: r['siteId'] as int,
          icon: Icons.currency_rupee,
          title: 'Payment overdue: ${r['siteName']}',
          subtitle:
              '${r['invoiceNumber']} · ${inr((r['balance'] as num).toDouble())} due',
          pill: overdueDays == 0 ? 'Due today' : '$overdueDays days',
          pillBg: _red,
          pillFg: _redText,
          priority: 1000 + overdueDays,
        ));
      }
    }

    // ----- PO received, no invoice yet -----
    for (final r in awaiting) {
      list.add(_Alert(
        siteId: r['siteId'] as int,
        icon: Icons.receipt_long,
        title: 'Invoice due: ${r['siteName']}',
        subtitle: 'PO ${r['label']}, no invoice yet',
        pill: 'To do',
        pillBg: _amber,
        pillFg: _amberText,
        priority: 500,
      ));
    }

    // ----- attendance not entered -----
    Future<void> addAttendance(DateTime start, DateTime end, String pill, int pr) async {
      final rows = await db.getSitesMissingAttendance(start, end);
      for (final r in rows) {
        list.add(_Alert(
          siteId: r['siteId'] as int,
          icon: Icons.groups_outlined,
          title: 'Attendance not entered: ${r['siteName']}',
          subtitle: '${monthLabel(start)} · ${r['workers']} workers',
          pill: pill,
          pillBg: _amber,
          pillFg: _amberText,
          priority: pr,
        ));
      }
    }

    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = DateTime(now.year, now.month, 0);
    await addAttendance(prevStart, prevEnd, 'Last month', 400);
    if (now.day >= 25) {
      await addAttendance(
        monthStart,
        DateTime(now.year, now.month + 1, 0),
        'This month',
        350,
      );
    }

    // ----- PO almost fully billed -----
    for (final r in poStatus) {
      final value = (r['poValue'] as num).toDouble();
      final billedPo = (r['billed'] as num).toDouble();
      final pct = billedPo / value * 100;
      if (pct >= 90 && pct < 100) {
        list.add(_Alert(
          siteId: r['siteId'] as int,
          icon: Icons.pie_chart_outline,
          title: 'PO almost fully billed: ${r['siteName']}',
          subtitle: '${pct.round()}% of ${inr(value)} billed (PO ${r['label']})',
          pill: 'Check',
          pillBg: _amber,
          pillFg: _amberText,
          priority: 200,
        ));
      }
    }

    list.sort((a, b) => b.priority.compareTo(a.priority));

    if (!mounted) return;
    setState(() {
      outstanding = out;
      receivedMonth = received;
      billedMonth = billed;
      alerts
        ..clear()
        ..addAll(list);
      projects
        ..clear()
        ..addAll(summaries.map((r) => _Project(
              r['id'] as int,
              '${r['name']}',
              (r['poValue'] as num).toDouble(),
              (r['billed'] as num).toDouble(),
              (r['due'] as num).toDouble(),
            )));
      loading = false;
    });
  }

  Future<void> openSite(int siteId) async {
    final site = await DatabaseHelper.instance.getSiteById(siteId);
    if (site == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SiteDetailPage(site: site)),
    );
    load();
  }

  /// Asks which active project (skips the question when there is only one).
  Future<Site?> pickSite() async {
    final rows = await DatabaseHelper.instance.getSites();
    final sites = rows
        .map((e) => Site.fromMap(e))
        .where((s) => s.status == 'Active')
        .toList();

    if (!mounted) return null;
    if (sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an active project first.')),
      );
      return null;
    }
    if (sites.length == 1) return sites.first;

    return showDialog<Site>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Which project?'),
        children: [
          for (final s in sites)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(s.name),
            ),
        ],
      ),
    );
  }

  Future<void> markAttendance() async {
    final site = await pickSite();
    if (site == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendancePage(site: site)),
    );
    load();
  }

  Future<void> createPackage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PackagePage()),
    );
    load();
  }

  Future<void> newInvoice() async {
    final site = await pickSite();
    if (site == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GenerateInvoicePage(site: site)),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final month = _monthShort[DateTime.now().month - 1];

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = [
      ('Outstanding', inr(outstanding)),
      ('Received in $month', inr(receivedMonth)),
      ('Billed in $month', inr(billedMonth)),
      ('Active projects', '${projects.length}'),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            // ===== brand header =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MARS ENGINEERS',
                        style: TextStyle(
                          color: kBrandRed,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MAKE IT POSSIBLE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: load,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 2, color: kBrandRed),
            const SizedBox(height: 18),

            // ===== summary cards =====
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 640 ? 4 : 2;
                final w = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final s in stats)
                      SizedBox(width: w, child: _statCard(s.$1, s.$2, scheme)),
                  ],
                );
              },
            ),

            // ===== needs action =====
            _sectionTitle('Needs action', scheme),
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 36, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    const Text('Nothing needs action'),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < alerts.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                      _alertRow(alerts[i], scheme),
                    ],
                  ],
                ),
              ),

            // ===== active projects =====
            _sectionTitle('Active projects', scheme),
            if (projects.isEmpty)
              const Text('No active projects yet. Add one in the Projects tab.')
            else
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
                  final w = (c.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final p in projects)
                        SizedBox(width: w, child: _projectCard(p, scheme)),
                    ],
                  );
                },
              ),

            // ===== quick buttons =====
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: markAttendance,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Mark attendance'),
                ),
                OutlinedButton.icon(
                  onPressed: createPackage,
                  icon: const Icon(Icons.file_copy_outlined),
                  label: const Text('Create package'),
                ),
                FilledButton.icon(
                  onPressed: newInvoice,
                  icon: const Icon(Icons.add),
                  label: const Text('New invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _statCard(String label, String value, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _alertRow(_Alert a, ColorScheme scheme) {
    return InkWell(
      onTap: () => openSite(a.siteId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(a.icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(a.subtitle,
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: a.pillBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(a.pill,
                  style: TextStyle(fontSize: 12, color: a.pillFg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(_Project p, ColorScheme scheme) {
    final hasPo = p.poValue > 0;
    final pct = hasPo ? (p.billed / p.poValue).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openSite(p.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hasPo ? pct : 0,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPo
                  ? '${inr(p.billed)} of ${inr(p.poValue)} billed'
                  : 'No PO added yet',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            Text(
              p.due > 0.5 ? '${inr(p.due)} to collect' : 'Nothing due',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
