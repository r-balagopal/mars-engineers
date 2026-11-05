import 'package:shared_preferences/shared_preferences.dart';

/// Company / invoice settings kept on this device.
class InvoiceSettings {
  static const defaultPrefix = '2026-27/';
  static const defaultStart = 30;

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<String> apiKey() async =>
      (await _p).getString('apiKey')?.trim() ?? '';

  static Future<String> prefix() async {
    final v = (await _p).getString('prefix')?.trim() ?? '';
    return v.isEmpty ? defaultPrefix : v;
  }

  /// Lowest number the next invoice may use.
  static Future<int> startNumber() async {
    final v = int.tryParse((await _p).getString('startNumber')?.trim() ?? '');
    return (v == null || v < 1) ? defaultStart : v;
  }

  static Future<void> save({
    required String apiKey,
    required String prefix,
    required String startNumber,
  }) async {
    final p = await _p;
    await p.setString('apiKey', apiKey.trim());
    await p.setString('prefix', prefix.trim());
    await p.setString('startNumber', startNumber.trim());
  }
}
