import 'package:flutter/material.dart';

import '../../models/team_member.dart';

class TeamMemberDialog extends StatefulWidget {
  final int siteId;
  final TeamMember? member;

  const TeamMemberDialog({
    super.key,
    required this.siteId,
    this.member,
  });

  @override
  State<TeamMemberDialog> createState() => _TeamMemberDialogState();
}

class _TeamMemberDialogState extends State<TeamMemberDialog> {
  final nameController = TextEditingController();
  final dailyRateController = TextEditingController();

  final List<String> designations = [
    'Supervisor',
    'Rigger',
    'Helper',
    'Electrician',
    'Plumber',
    'Welder',
    'Other',
  ];

  String designation = 'Supervisor';

  DateTime? startDate;
  DateTime? endDate;

  @override
void initState() {
  super.initState();

  if (widget.member != null) {
    nameController.text = widget.member!.name;
    dailyRateController.text =
        widget.member!.dailyRate.toStringAsFixed(0);

    designation = widget.member!.designation;

    startDate = DateTime.parse(widget.member!.startDate);

    if (widget.member!.endDate != null &&
        widget.member!.endDate!.isNotEmpty) {
      endDate = DateTime.parse(widget.member!.endDate!);
    }
  }
}

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
  widget.member == null
      ? 'Add Team Member'
      : 'Edit Team Member',
),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: designation,
              decoration: const InputDecoration(
                labelText: 'Designation',
              ),
              items: designations
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  designation = value!;
                });
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: dailyRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Rate (₹)',
              ),
            ),

            const SizedBox(height: 20),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(
                startDate == null
                    ? 'Select Date'
                    : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickStartDate,
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End Date (Optional)'),
              subtitle: Text(
                endDate == null
                    ? 'Select Date'
                    : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickEndDate,
            ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isEmpty) return;
            if (dailyRateController.text.trim().isEmpty) return;
            if (startDate == null) return;

            Navigator.pop(
              context,
              TeamMember(
  id: widget.member?.id,
  siteId: widget.siteId,
                name: nameController.text.trim(),
                designation: designation,
                dailyRate: double.parse(dailyRateController.text),
                startDate: startDate!.toIso8601String(),
                endDate: endDate?.toIso8601String(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}