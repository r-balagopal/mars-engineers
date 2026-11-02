import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
           ElevatedButton.icon(
  onPressed: () async {
    final backupPath =
        await DatabaseHelper.instance.backupDatabase();

    await Share.shareXFiles(
      [XFile(backupPath)],
      text: 'Mars Engineers Backup',
    );
  },
  icon: const Icon(Icons.backup),
  label: const Text('Backup Database'),
),

            const SizedBox(height: 20),

           ElevatedButton.icon(
  onPressed: () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null) return;

    final backupPath = result.files.single.path;

    if (backupPath == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Database?'),
          content: const Text(
            'This will replace all current data with the selected backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.restoreDatabase(
        backupPath,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Database restored. Please restart the app.',
            ),
          ),
        );
      }
    }
  },
  icon: const Icon(Icons.restore),
  label: const Text('Restore Database'),
),
          ],
        ),
      ),
    );
  }
}