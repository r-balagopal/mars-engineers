import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/site.dart';
import '../models/team_member.dart';
import '../models/work_order.dart';
import '../widgets/site_detail/invoice_dialog.dart';
import 'attendance_page.dart';
import 'generate_invoice_page.dart';
import 'package_page.dart';
import '../services/manpower_statement.dart';
import '../services/pdf_opener.dart';
import '../widgets/site_detail/invoices_tab.dart';
import '../widgets/site_detail/overview_tab.dart';
import '../widgets/site_detail/po_dialog.dart';
import '../widgets/site_detail/po_tab.dart';
import '../widgets/site_detail/team_member_dialog.dart';
import '../widgets/site_detail/team_tab.dart';

class SiteDetailPage extends StatefulWidget {
  final Site site;

  const SiteDetailPage({
    super.key,
    required this.site,
  });

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  int currentTab = 0;

  List<Invoice> invoices = [];
  List<WorkOrder> pos = [];
  List<TeamMember> teamMembers = [];

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 4, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging && currentTab != tabController.index) {
        setState(() => currentTab = tabController.index);
      }
    });

    loadAll();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    final db = DatabaseHelper.instance;
    final id = widget.site.id!;

    final inv = await db.getInvoicesBySite(id);
    final po = await db.getWorkOrdersBySite(id);
    final team = await db.getTeamMembersBySite(id);

    if (!mounted) return;
    setState(() {
      invoices = inv.map((e) => Invoice.fromMap(e)).toList();
      pos = po.map((e) => WorkOrder.fromMap(e)).toList();
      teamMembers = team.map((e) => TeamMember.fromMap(e)).toList();
    });
  }

  // ---------- POs ----------

  Future<void> showPoDialog([WorkOrder? po]) async {
    final result = await showDialog<WorkOrder>(
      context: context,
      builder: (_) => PoDialog(siteId: widget.site.id!, po: po),
    );
    if (result == null) return;

    if (po == null) {
      await DatabaseHelper.instance.insertPo(result);
    } else {
      await DatabaseHelper.instance.updatePo(result);
    }
    await loadAll();
  }

  Future<void> confirmDeletePo(WorkOrder po) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete PO?'),
        content: Text(
          'Delete PO ${po.label}? Invoices linked to it stay, '
          'but become "No PO".',
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

    await DatabaseHelper.instance.deleteWorkOrder(po.id!);
    await loadAll();
  }

  // ---------- Invoices ----------

  Future<void> showInvoiceDialog([Invoice? invoice]) async {
    await showDialog(
      context: context,
      builder: (_) => InvoiceDialog(
        siteId: widget.site.id!,
        pos: pos,
        invoice: invoice,
        onChanged: loadAll,
      ),
    );
  }

  Future<void> generateInvoice() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GenerateInvoicePage(site: widget.site),
      ),
    );
    if (saved == true) await loadAll();
  }

  // ---------- Manpower ----------

  Future<void> openAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendancePage(site: widget.site)),
    );
    await loadAll();
  }

  Future<void> makeStatement() async {
    final range = await pickStatementRange(context);
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



  Future<void> showAddTeamMemberDialog() async {
    final TeamMember? member = await showDialog<TeamMember>(
      context: context,
      builder: (_) => TeamMemberDialog(siteId: widget.site.id!),
    );
    if (member == null) return;

    await DatabaseHelper.instance.insertTeamMember(member);
    await loadAll();
  }

  Future<void> showEditTeamMemberDialog(TeamMember member) async {
    final TeamMember? updated = await showDialog<TeamMember>(
      context: context,
      builder: (_) => TeamMemberDialog(
        siteId: widget.site.id!,
        member: member,
      ),
    );
    if (updated == null) return;

    await DatabaseHelper.instance.updateTeamMember(updated);
    await loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        actions: [
          if (currentTab == 2) ...[
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PackagePage(site: widget.site),
                ),
              ),
              icon: const Icon(Icons.file_copy_outlined),
              label: const Text('Package'),
            ),
            TextButton.icon(
              onPressed: () => showInvoiceDialog(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Add manually'),
            ),
          ],
          if (currentTab == 3) ...[
            TextButton.icon(
              onPressed: openAttendance,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Attendance'),
            ),
            TextButton.icon(
              onPressed: makeStatement,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Statement'),
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'POs'),
            Tab(text: 'Invoices'),
            Tab(text: 'Manpower'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          OverviewTab(site: widget.site, pos: pos, invoices: invoices),
          PoTab(
            pos: pos,
            invoices: invoices,
            onEdit: showPoDialog,
            onDelete: confirmDeletePo,
          ),
          InvoicesTab(
            invoices: invoices,
            pos: pos,
            onInvoiceTap: showInvoiceDialog,
          ),
          TeamTab(
            members: teamMembers,
            onEdit: (member) async {
              await showEditTeamMemberDialog(member);
            },
            onDelete: (member) async {
              await DatabaseHelper.instance.deleteTeamMember(member.id!);
              await loadAll();
            },
          ),
        ],
      ),
      floatingActionButton: switch (currentTab) {
        1 => FloatingActionButton.extended(
            onPressed: () => showPoDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add PO'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: generateInvoice,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate invoice'),
          ),
        3 => FloatingActionButton.extended(
            onPressed: showAddTeamMemberDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Add member'),
          ),
        _ => null,
      },
    );
  }
}
