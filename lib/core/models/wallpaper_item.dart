enum WallpaperSource {
  pexels,
  pixabay,
  wallhaven,
  nasa,
  waifu,
  curated,
  local,
}

enum WallpaperMediaType {
  image,
  video,
}

class WallpaperItem {
  final String id;
  final String title;
  final String author;
  final String authorUrl;
  final String previewUrl;
  final String fullUrl;
  final String rawUrl;
  final String? videoUrl; // For Live Video wallpapers
  final String? blurHash;
  final int width;
  final int height;
  final WallpaperMediaType mediaType;
  final WallpaperSource source;
  final List<String> tags;
  final String? localCachedPath;
  final DateTime createdAt;

  WallpaperItem({
    required this.id,
    required this.title,
    required this.author,
    this.authorUrl = '',
    required this.previewUrl,
    required this.fullUrl,
    required this.rawUrl,
    this.videoUrl,
    this.blurHash,
    this.width = 1080,
    this.height = 1920,
    this.mediaType = WallpaperMediaType.image,
    required this.source,
    this.tags = const [],
    this.localCachedPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isVideo => mediaType == WallpaperMediaType.video || (videoUrl != null && videoUrl!.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'authorUrl': authorUrl,
      'previewUrl': previewUrl,
      'fullUrl': fullUrl,
      'rawUrl': rawUrl,
      'videoUrl': videoUrl,
      'blurHash': blurHash,
      'width': width,
      'height': height,
      'mediaType': mediaType.name,
      'source': source.name,
      'tags': tags,
      'localCachedPath': localCachedPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WallpaperItem.fromJson(Map<String, dynamic> json) {
    return WallpaperItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Wallpaper',
      author: json['author'] as String? ?? 'Artist',
      authorUrl: json['authorUrl'] as String? ?? '',
      previewUrl: json['previewUrl'] as String? ?? '',
      fullUrl: json['fullUrl'] as String? ?? '',
      rawUrl: json['rawUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
      blurHash: json['blurHash'] as String?,
      width: json['width'] as int? ?? 1080,
      height: json['height'] as int? ?? 1920,
      mediaType: WallpaperMediaType.values.firstWhere(
        (e) => e.name == json['mediaType'],
        orElse: () => WallpaperMediaType.image,
      ),
      source: WallpaperSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => WallpaperSource.curated,
      ),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      localCachedPath: json['localCachedPath'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  WallpaperItem copyWith({
    String? id,
    String? title,
    String? author,
    String? authorUrl,
    String? previewUrl,
    String? fullUrl,
    String? rawUrl,
    String? videoUrl,
    String? blurHash,
    int? width,
    int? height,
    WallpaperMediaType? mediaType,
    WallpaperSource? source,
    List<String>? tags,
    String? localCachedPath,
    DateTime? createdAt,
  }) {
    return WallpaperItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      authorUrl: authorUrl ?? this.authorUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      rawUrl: rawUrl ?? this.rawUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      blurHash: blurHash ?? this.blurHash,
      width: width ?? this.width,
      height: height ?? this.height,
      mediaType: mediaType ?? this.mediaType,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      localCachedPath: localCachedPath ?? this.localCachedPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
