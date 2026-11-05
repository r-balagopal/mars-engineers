const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _group(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s
      .substring(0, s.length - 3)
      .replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '$rest,$last3';
}

/// Compact: ₹32,000 / ₹4.82 L / ₹1.20 Cr
String inr(double v) {
  if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)} L';
  return '₹${_group(v.round())}';
}

/// Full: ₹4,82,000
String inrFull(double v) => '₹${_group(v.round())}';

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String fmtIso(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '—' : fmtDate(d);
}

double? parseAmount(String s) =>
    double.tryParse(s.replaceAll(',', '').replaceAll('₹', '').trim());

/// 1,18,000.00 (Indian grouping, 2 decimals, no symbol)
String money2(double v) {
  final cents = (v * 100).round();
  final whole = cents ~/ 100;
  final frac = (cents % 100).toString().padLeft(2, '0');
  return '${_group(whole)}.$frac';
}

/// 05/11/2026
String fmtDmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// 2026-11-05 (used to store attendance dates)
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String monthLabel(DateTime d) {
  const m = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${m[d.month - 1]} ${d.year}';
}
