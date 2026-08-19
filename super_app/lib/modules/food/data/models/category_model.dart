import 'package:superapp_user/core/config/api_config.dart';

class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  /// Maps a backend category (`/food/restaurant/categories/public`) or an
  /// explore icon (`/food/explore-icons/public`, which uses `iconUrl`/`label`).
  factory CategoryModel.fromApi(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['label'] ?? '').toString(),
      imageUrl: ApiConfig.resolveMedia((json['image'] ?? json['iconUrl']) as String?),
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
    };
  }
}
