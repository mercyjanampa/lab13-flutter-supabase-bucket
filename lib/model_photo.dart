class PhotoModel {
  final String id;
  final String url;
  final String? description;
  final DateTime createdAt;

  PhotoModel({
    required this.id,
    required this.url,
    this.description,
    required this.createdAt,
  });

  factory PhotoModel.fromMap(Map<String, dynamic> map) {
    return PhotoModel(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
