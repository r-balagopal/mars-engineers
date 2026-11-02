import 'invoice.dart';

class Site {
  int? id;
  String name;
  String workType;
  String status;
  List<Invoice> invoices;
String? workOrderPath;

  Site({
  this.id,
  required this.name,
  required this.workType,
  required this.status,
  this.workOrderPath,
  List<Invoice>? invoices,
}) : invoices = invoices ?? [];

  Map<String, dynamic> toMap() {
    return {
  'id': id,
  'name': name,
  'workType': workType,
  'status': status,
  'workOrderPath': workOrderPath,
};
  }

  factory Site.fromMap(Map<String, dynamic> map) {
   return Site(
  id: map['id'],
  name: map['name'],
  workType: map['workType'],
  status: map['status'],
  workOrderPath: map['workOrderPath'],
  invoices: [],
);
  }
}