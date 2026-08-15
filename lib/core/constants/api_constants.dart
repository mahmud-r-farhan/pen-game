class ApiConstants {
  ApiConstants._();

  // Public/Fallback API Endpoints & Default Free Tier Tokens
  static const String pexelsBaseUrl = 'https://api.pexels.com/v1';
  static const String pexelsVideosBaseUrl = 'https://api.pexels.com/videos';
  static const String pixabayBaseUrl = 'https://pixabay.com/api';
  static const String wallhavenBaseUrl = 'https://wallhaven.cc/api/v1';
  static const String nasaApodUrl = 'https://api.nasa.gov/planetary/apod';
  static const String waifuPicsBaseUrl = 'https://api.waifu.pics';

  // Public demonstration & developer testing keys
  // Note: App supports custom user API keys entered via Settings UI as well as automatic provider failover!
  static const String defaultPexelsKey = '563492ad6f91700001000001da6606f23512411aa807358d7c49352e';
  static const String defaultPixabayKey = '49405021-394bf3cfb4c25f54ca2bc9e29';
  static const String defaultNasaKey = 'DEMO_KEY';
}
