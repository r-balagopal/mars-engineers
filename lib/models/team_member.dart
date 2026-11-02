class TeamMember {
  int? id;
  int siteId;
  String name;
  String designation;
  double dailyRate;
  String startDate;
  String? endDate;

  TeamMember({
    this.id,
    required this.siteId,
    required this.name,
    required this.designation,
    required this.dailyRate,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'name': name,
      'designation': designation,
      'dailyRate': dailyRate,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'],
      siteId: map['siteId'],
      name: map['name'],
      designation: map['designation'],
      dailyRate: (map['dailyRate'] as num).toDouble(),
      startDate: map['startDate'],
      endDate: map['endDate'],
    );
  }
}