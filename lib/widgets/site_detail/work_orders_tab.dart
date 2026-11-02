import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../database/database_helper.dart';
import '../../models/work_order.dart';

class WorkOrdersTab extends StatelessWidget {
  final int siteId;
  final List<WorkOrder> workOrders;
  final Future<void> Function() loadWorkOrders;

  const WorkOrdersTab({
    super.key,
    required this.siteId,
    required this.workOrders,
    required this.loadWorkOrders,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
       

        if (workOrders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No work orders attached"),
            ),
          ),

        ...workOrders.map((workOrder) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf),

              title: Text(workOrder.fileName),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () {
                      OpenFilex.open(workOrder.filePath);
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      Share.shareXFiles([
                        XFile(workOrder.filePath),
                      ]);
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await DatabaseHelper.instance
                          .deleteWorkOrder(workOrder.id!);

                      await loadWorkOrders();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}