class Invoice {
  int? id;
  int siteId;
  int? poId;
  String invoiceNumber;
  double amount;
  double paid;
  String status;
  String? pdfPath;
  String? invoiceDate;
  String? dataJson;

  Invoice({
    this.id,
    required this.siteId,
    this.poId,
    required this.invoiceNumber,
    required this.amount,
    this.paid = 0,
    required this.status,
    this.pdfPath,
    this.invoiceDate,
    this.dataJson,
  });

  double get balance => amount - paid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'poId': poId,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'status': status,
      'pdfPath': pdfPath,
      'invoiceDate': invoiceDate,
      'dataJson': dataJson,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      siteId: map['siteId'],
      poId: map['poId'],
      invoiceNumber: map['invoiceNumber'],
      amount: (map['amount'] as num).toDouble(),
      paid: ((map['paid'] as num?) ?? 0).toDouble(),
      status: map['status'],
      pdfPath: map['pdfPath'],
      invoiceDate: map['invoiceDate'],
      dataJson: map['dataJson'],
    );
  }
}
