/// Result of `GET /food/zones/detect`.
///
/// Out-of-coverage is still HTTP 200 with `status: "OUT_OF_SERVICE"` — always
/// branch on [isInService], never on the status code.
class ZoneModel {
  final String status;
  final String? zoneId;
  final String? name;

  const ZoneModel({required this.status, this.zoneId, this.name});

  bool get isInService => status == 'IN_SERVICE' && (zoneId?.isNotEmpty ?? false);

  static const ZoneModel unknown = ZoneModel(status: 'UNKNOWN');

  factory ZoneModel.fromApi(Map<String, dynamic> json) {
    final zone = json['zone'];
    return ZoneModel(
      status: (json['status'] ?? 'UNKNOWN').toString(),
      zoneId: json['zoneId']?.toString(),
      name: zone is Map ? (zone['zoneName'] ?? zone['name'])?.toString() : null,
    );
  }
}
