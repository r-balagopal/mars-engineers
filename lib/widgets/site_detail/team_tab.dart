import 'package:flutter/material.dart';

import '../../models/team_member.dart';

class TeamTab extends StatelessWidget {
  final List<TeamMember> members;
  final Function(TeamMember) onEdit;
  final Function(TeamMember) onDelete;

  const TeamTab({
    super.key,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(
        child: Text(
          'No team members yet',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];

        final active =
            member.endDate == null ||
            member.endDate!.trim().isEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),

            title: Text(
              member.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(member.designation),

                Text(
                  '₹${member.dailyRate.toStringAsFixed(0)}/day',
                ),

                const SizedBox(height: 4),

                Text(
                  active
                      ? '🟢 Active'
                      : '⚫ Completed',
                ),
              ],
            ),

            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => onEdit(member),
                ),

                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onDelete(member),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}