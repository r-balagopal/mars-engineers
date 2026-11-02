class Invoice {
  int? id;
  int siteId;
  String invoiceNumber;
  double amount;
  String status;
  String? pdfPath;

  Invoice({
    this.id,
    required this.siteId,
    required this.invoiceNumber,
    required this.amount,
    required this.status,
    this.pdfPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'status': status,
      'pdfPath': pdfPath,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      siteId: map['siteId'],
      invoiceNumber: map['invoiceNumber'],
      amount: map['amount'].toDouble(),
      status: map['status'],
      pdfPath: map['pdfPath'],
    );
  }
}