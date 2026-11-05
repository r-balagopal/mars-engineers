/// A purchase order (PO) received for a project.
/// Stored in the `work_orders` table. `filePath` is '' when no file attached.
class WorkOrder {
  int? id;
  int siteId;
  String fileName;
  String filePath;
  String? poNumber;
  double? poValue;
  String? poDate;
  int paymentTermsDays;

  WorkOrder({
    this.id,
    required this.siteId,
    this.fileName = '',
    this.filePath = '',
    this.poNumber,
    this.poValue,
    this.poDate,
    this.paymentTermsDays = 30,
  });

  bool get hasFile => filePath.isNotEmpty;

  /// What to show as the PO's name.
  String get label =>
      (poNumber != null && poNumber!.isNotEmpty) ? poNumber! : fileName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'fileName': fileName,
      'filePath': filePath,
      'poNumber': poNumber,
      'poValue': poValue,
      'poDate': poDate,
      'paymentTermsDays': paymentTermsDays,
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'],
      siteId: map['siteId'],
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      poNumber: map['poNumber'],
      poValue: (map['poValue'] as num?)?.toDouble(),
      poDate: map['poDate'],
      paymentTermsDays: (map['paymentTermsDays'] as int?) ?? 30,
    );
  }
}
