class News {
  final int id;
  final String title;
  final String description;
  final String sourceUrl;
  final String? imageUrl;
  final DateTime? publishedDate;
  final String? source;
  final String? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const News({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceUrl,
    this.imageUrl,
    this.publishedDate,
    this.source,
    this.category,
    this.createdAt,
    this.updatedAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      sourceUrl: json['sourceUrl'] as String,
      imageUrl: json['imageUrl'] as String?,
      publishedDate: json['publishedDate'] != null
          ? DateTime.parse(json['publishedDate'] as String)
          : null,
      source: json['source'] as String?,
      category: json['category'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'publishedDate': publishedDate?.toIso8601String(),
      'source': source,
      'category': category,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class NewsResponse {
  final List<News> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const NewsResponse({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    return NewsResponse(
      content: (json['content'] as List<dynamic>?)
          ?.map((item) => News.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      number: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      last: json['last'] as bool? ?? false,
    );
  }
}
