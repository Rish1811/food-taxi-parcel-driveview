class ParcelModel {
  final String category;
  final String weight;
  final String description;
  final String senderName;
  final String senderMobile;
  final String receiverName;
  final String receiverMobile;
  final bool isOutstation;

  const ParcelModel({
    this.category = '',
    this.weight = '',
    this.description = '',
    this.senderName = '',
    this.senderMobile = '',
    this.receiverName = '',
    this.receiverMobile = '',
    this.isOutstation = false,
  });

  factory ParcelModel.fromJson(Map<String, dynamic> json) {
    return ParcelModel(
      category: (json['category'] ?? '').toString(),
      weight: (json['weight'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      senderMobile: (json['senderMobile'] ?? '').toString(),
      receiverName: (json['receiverName'] ?? '').toString(),
      receiverMobile: (json['receiverMobile'] ?? '').toString(),
      isOutstation: json['isOutstation'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'weight': weight,
      'description': description,
      'deliveryCategory': category,
      'deliveryScope': isOutstation ? 'outstation' : 'city',
      'isOutstation': isOutstation,
      'senderName': senderName,
      'senderMobile': senderMobile,
      'receiverName': receiverName,
      'receiverMobile': receiverMobile,
    };
  }
}
