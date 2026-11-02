import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/site.dart';
import '../models/invoice.dart';
import '../database/database_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/work_order.dart';

import '../widgets/site_detail/overview_tab.dart';
import '../widgets/site_detail/work_orders_tab.dart';
import '../widgets/site_detail/invoices_tab.dart';
import '../widgets/site_detail/team_tab.dart';
import '../models/team_member.dart';
import '../widgets/site_detail/team_member_dialog.dart';

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
  int invoiceCount = 0;
  double totalInvoiced = 0;
  double totalPaid = 0;
  double totalOutstanding = 0;
  int currentTab = 0;

  final invoiceNumberController = TextEditingController();
  final amountController = TextEditingController();

  String invoiceStatus = 'Pending';

  late TabController tabController;

  List<Invoice> invoices = [];
  List<WorkOrder> workOrders = [];
  List<TeamMember> teamMembers = [];

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 4,
      vsync: this,
    );

    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        setState(() {
          currentTab = tabController.index;
        });
      }
    });

    loadInvoices();
    loadWorkOrders();
    loadTeamMembers();
  }

  @override
  void dispose() {
    tabController.dispose();
    invoiceNumberController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> loadInvoices() async {
    final data = await DatabaseHelper.instance.getInvoicesBySite(widget.site.id!);
    setState(() {
      invoices = data.map((e) => Invoice.fromMap(e)).toList();
      calculateStats();
    });
  }

  Future<void> addWorkOrder() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    final path = result.files.single.path;
    if (path == null) return;

    await DatabaseHelper.instance.insertWorkOrder(
      widget.site.id!,
      result.files.single.name,
      path,
    );

    await loadWorkOrders();
  }

  Future<void> loadWorkOrders() async {
    final data = await DatabaseHelper.instance.getWorkOrdersBySite(widget.site.id!);
    setState(() {
      workOrders = data.map((e) => WorkOrder.fromMap(e)).toList();
    });
  }

  Future<void> loadTeamMembers() async {
    final data = await DatabaseHelper.instance.getTeamMembersBySite(widget.site.id!);
    setState(() {
      teamMembers = data.map((e) => TeamMember.fromMap(e)).toList();
    });
  }

  Future<void> showAddTeamMemberDialog() async {
    final TeamMember? member = await showDialog<TeamMember>(
      context: context,
      builder: (_) => TeamMemberDialog(
        siteId: widget.site.id!,
      ),
    );

    if (member == null) return;

    await DatabaseHelper.instance.insertTeamMember(member);

    await loadTeamMembers();
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

    await loadTeamMembers();
  }

  void calculateStats() {
    invoiceCount = invoices.length;
    totalInvoiced = 0;
    totalPaid = 0;
    totalOutstanding = 0;

    for (final invoice in invoices) {
      totalInvoiced += invoice.amount;
      if (invoice.status == 'Paid') {
        totalPaid += invoice.amount;
      } else {
        totalOutstanding += invoice.amount;
      }
    }
  }

  void showAddInvoiceDialog() {
    invoiceNumberController.clear();
    amountController.clear();
    invoiceStatus = 'Pending';
    String? selectedPdfPath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: invoiceNumberController,
                    decoration: const InputDecoration(labelText: 'Invoice Number'),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: invoiceStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        invoiceStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null) {
                        setDialogState(() {
                          selectedPdfPath = result.files.single.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach PDF'),
                  ),
                  if (selectedPdfPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Selected: ${selectedPdfPath!.split('\\').last}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (invoiceNumberController.text.isNotEmpty &&
                        amountController.text.isNotEmpty) {
                      await DatabaseHelper.instance.insertInvoice(
                        widget.site.id!,
                        invoiceNumberController.text,
                        double.parse(amountController.text),
                        invoiceStatus,
                        selectedPdfPath,
                      );
                      selectedPdfPath = null;
                      if (context.mounted) Navigator.pop(context);
                      await loadInvoices();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showEditInvoiceDialog(Invoice invoice) {
    invoiceNumberController.text = invoice.invoiceNumber;
    amountController.text = invoice.amount.toString();
    invoiceStatus = invoice.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: invoiceNumberController,
                    decoration: const InputDecoration(labelText: 'Invoice Number'),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: invoiceStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        invoiceStatus = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await DatabaseHelper.instance.updateInvoice(
                      invoice.id!,
                      invoiceNumberController.text,
                      double.parse(amountController.text),
                      invoiceStatus,
                    );
                    if (context.mounted) Navigator.pop(context);
                    await loadInvoices();
                  },
                  child: const Text('Save'),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Invoice'),
                        content: Text(
                          'Are you sure you want to delete "${invoice.invoiceNumber}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteInvoice(invoice.id!);
                              if (context.mounted) {
                                Navigator.pop(context); // close confirm dialog
                                Navigator.pop(context); // close edit dialog
                              }
                              await loadInvoices();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.description), text: 'Work Orders'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
            Tab(icon: Icon(Icons.groups), text: 'Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          OverviewTab(
            siteName: widget.site.name,
            workType: widget.site.workType,
            status: widget.site.status,
            invoiceCount: invoiceCount,
            totalInvoiced: totalInvoiced,
            totalPaid: totalPaid,
            totalOutstanding: totalOutstanding,
          ),
          WorkOrdersTab(
            siteId: widget.site.id!,
            workOrders: workOrders,
            loadWorkOrders: loadWorkOrders,
          ),
          InvoicesTab(
            invoices: invoices,
            onInvoiceTap: showEditInvoiceDialog,
          ),
          TeamTab(
            members: teamMembers,
            onEdit: (member) async {
              await showEditTeamMemberDialog(member);
            },
            onDelete: (member) async {
              await DatabaseHelper.instance.deleteTeamMember(member.id!);
              await loadTeamMembers();
            },
          ),
        ],
      ),
      floatingActionButton: switch (currentTab) {
        0 => null,
        1 => FloatingActionButton(
            onPressed: addWorkOrder,
            child: const Icon(Icons.upload_file),
          ),
        2 => FloatingActionButton(
            onPressed: showAddInvoiceDialog,
            child: const Icon(Icons.add),
          ),
        3 => FloatingActionButton(
            onPressed: showAddTeamMemberDialog,
            child: const Icon(Icons.person_add),
          ),
        _ => null,
      },
    );
  }
}