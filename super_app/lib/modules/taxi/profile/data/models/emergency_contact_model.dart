class EmergencyContactModel {
  final String id;
  final String name;
  final String phone;
  final String relation;

  const EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = 'Other',
  });

  factory EmergencyContactModel.fromJson(Map<dynamic, dynamic> json) {
    return EmergencyContactModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      relation: (json['relation'] ?? 'Other').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
      };
}
