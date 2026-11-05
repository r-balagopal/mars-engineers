class Payment {
  int? id;
  int invoiceId;
  double amount;
  String paidDate;
  String? reference;

  Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.paidDate,
    this.reference,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      invoiceId: map['invoiceId'],
      amount: (map['amount'] as num).toDouble(),
      paidDate: map['paidDate'],
      reference: map['reference'],
    );
  }
}
