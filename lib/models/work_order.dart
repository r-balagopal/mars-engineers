class WorkOrder {
  int? id;
  int siteId;
  String fileName;
  String filePath;

  WorkOrder({
    this.id,
    required this.siteId,
    required this.fileName,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'fileName': fileName,
      'filePath': filePath,
    };
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'],
      siteId: map['siteId'],
      fileName: map['fileName'],
      filePath: map['filePath'],
    );
  }
}