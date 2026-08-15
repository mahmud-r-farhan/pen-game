class WallpaperCategory {
  final String id;
  final String title;
  final String icon;
  final String searchQuery;
  final String previewImage;

  const WallpaperCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.searchQuery,
    required this.previewImage,
  });

  static const List<WallpaperCategory> defaultCategories = [
    WallpaperCategory(
      id: 'curated',
      title: 'Curated 4K',
      icon: '✨',
      searchQuery: '4k wallpaper aesthetic',
      previewImage: 'https://images.pexels.com/photos/1323550/pexels-photo-1323550.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'amoled',
      title: 'AMOLED & Dark',
      icon: '🖤',
      searchQuery: 'dark amoled minimalist wallpaper',
      previewImage: 'https://images.pexels.com/photos/1252890/pexels-photo-1252890.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'anime',
      title: 'Anime Art',
      icon: '🌸',
      searchQuery: 'anime landscape aesthetic wallpaper',
      previewImage: 'https://images.pexels.com/photos/1820563/pexels-photo-1820563.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'nature',
      title: 'Nature & Earth',
      icon: '🌲',
      searchQuery: 'nature mountains landscape 4k wallpaper',
      previewImage: 'https://images.pexels.com/photos/2662116/pexels-photo-2662116.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'space',
      title: 'Space & Cosmic',
      icon: '🚀',
      searchQuery: 'galaxy nebula space astronomy wallpaper',
      previewImage: 'https://images.pexels.com/photos/2150/sky-space-dark-galaxy.jpg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'cyberpunk',
      title: 'Cyberpunk & Neon',
      icon: '⚡',
      searchQuery: 'cyberpunk neon city futuristic wallpaper',
      previewImage: 'https://images.pexels.com/photos/3052361/pexels-photo-3052361.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'minimal',
      title: 'Minimal & Clean',
      icon: '⚪',
      searchQuery: 'minimalist clean geometry abstract wallpaper',
      previewImage: 'https://images.pexels.com/photos/2088203/pexels-photo-2088203.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
    WallpaperCategory(
      id: 'cars',
      title: 'Supercars & Speed',
      icon: '🏎️',
      searchQuery: 'supercar dark moody luxury automotive wallpaper',
      previewImage: 'https://images.pexels.com/photos/337909/pexels-photo-337909.jpeg?auto=compress&cs=tinysrgb&w=600',
    ),
  ];
}
