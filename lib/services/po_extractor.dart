import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const kGeminiModel = 'gemini-3.8-flash';
const kFallbackModel = 'gemini-3.6-flash'; // used if the main model is busy

/// Reads a purchase order (PDF / image) with the Gemini API and returns the
/// extracted fields as JSON: po_number, client_name, client_gstin,
/// client_address, tax_type, gst_rate, items[].
Future<Map<String, dynamic>> extractPo({
  required Uint8List bytes,
  required String extension,
  required String apiKey,
}) async {
  final ext = extension.toLowerCase();
  final isPdf = ext == 'pdf';
  final media = isPdf ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
  final part = {
    'inline_data': {'mime_type': media, 'data': base64Encode(bytes)}
  };
  const prompt = '''
Extract data from this purchase order (PO). Return ONLY a JSON object, no markdown:
{
 "po_number": string,
 "client_name": string,
 "client_gstin": string,
 "client_address": string,
 "tax_type": "IGST" | "CGST_SGST" | null,
 "gst_rate": number | null,
 "items": [ {"description": string, "sac_code": string, "unit": string, "quantity": number | null, "rate": number | null} ]
}
Rules:
- client_name: legal name of the company the invoice must be issued in, as written in the PO's terms/invoicing instructions if present, otherwise the company name in the PO header. Normal capitalisation. NOT a site, plant or project name.
- client_gstin and client_address: from the "Invoice to" block. Not the vendor and not the delivery address.
- description: item name only. Remove the material code prefix (e.g. "1020001430/") and any trailing hyphen.
- sac_code: HSN/SAC column. unit: UOM column.
- rate: unit rate before tax. quantity: as printed.
- tax_type and gst_rate: as printed on the PO's item tax lines.
- Use null for anything not printed in the PO. Never calculate, estimate or guess.
- One entry per line item, in PO order.''';
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          part,
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'thinkingConfig': {'thinkingLevel': 'low'}, // faster reply
    },
  });

  http.Response? res;
  Object? lastErr;
  models:
  for (final m in [kGeminiModel, kFallbackModel]) {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent');
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final r = await http
            .post(url,
                headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
                body: body)
            .timeout(const Duration(seconds: 120));
        if (r.statusCode == 404) {
          lastErr = 'API 404: ${r.body}';
          break; // model not available: try the next one
        }
        if (r.statusCode == 429 || r.statusCode >= 500) {
          lastErr = 'API ${r.statusCode}: ${r.body}'; // busy: wait and retry
          await Future.delayed(Duration(seconds: 3 * attempt));
          continue;
        }
        res = r;
        break models;
      } catch (e) {
        lastErr = e;
        final t = '$e';
        if (!t.contains('ClientException') && !t.contains('Socket')) rethrow;
        await Future.delayed(const Duration(seconds: 2)); // network dropped: retry
      }
    }
  }
  if (res == null) throw lastErr ?? 'No response';
  if (res.statusCode != 200) throw 'API ${res.statusCode}: ${res.body}';
  final text = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'] as String;
  final s = text.indexOf('{'), e = text.lastIndexOf('}');
  return jsonDecode(text.substring(s, e + 1));
}

String numText(dynamic v) {
  if (v == null) return '';
  if (v is num) return v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());
  final p = double.tryParse('$v');
  return p == null || p == 0 ? '' : numText(p);
}

String cleanDesc(String s) => s
    .replaceFirst(RegExp(r'^\s*\d+\s*/\s*'), '')
    .replaceFirst(RegExp(r'[\s\-–]+$'), '')
    .trim();
