import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final String text;

  const StatusPill(this.text, {super.key});

  static const _green = (Color(0xFFDDF3E1), Color(0xFF1B6B2F));
  static const _amber = (Color(0xFFFFF0CC), Color(0xFF8A5A00));
  static const _red = (Color(0xFFFCE4E4), Color(0xFFB3261E));
  static const _grey = (Color(0xFFE8E8EC), Color(0xFF494951));

  @override
  Widget build(BuildContext context) {
    final c = switch (text) {
      'Paid' || 'Active' || 'Saved' => _green,
      'Part paid' || 'Pending' => _amber,
      'Overdue' => _red,
      _ => _grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.$1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: c.$2)),
    );
  }
}
