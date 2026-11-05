import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Opens a file. On Windows, PDFs open in Google Chrome when it is installed;
/// otherwise (or for other platforms / file types) the system default app.
Future<void> openFile(String path) async {
  if (Platform.isWindows && path.toLowerCase().endsWith('.pdf')) {
    if (await _openInChrome(path)) return;
  }
  await OpenFilex.open(path);
}

Future<bool> _openInChrome(String path) async {
  final candidates = <String>[
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    '${Platform.environment['LOCALAPPDATA'] ?? ''}'
        r'\Google\Chrome\Application\chrome.exe',
  ];

  for (final exe in candidates) {
    if (await File(exe).exists()) {
      try {
        await Process.start(exe, [path], mode: ProcessStartMode.detached);
        return true;
      } catch (_) {}
    }
  }

  // Chrome registered on PATH / App Paths
  try {
    final r = await Process.run('cmd', ['/c', 'start', '', 'chrome', path]);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}
