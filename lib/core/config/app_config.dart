class AppConfig {
  AppConfig._();

  static const String _serverBase = 'http://62.151.182.241:4055';

  // Override at build time: --dart-define=API_BASE=https://your-domain.com
  static const String _envBase =
      String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl => _envBase.isNotEmpty ? _envBase : _serverBase;
  static String get graphqlUrl => '$baseUrl/workfreeli';
  static String get refreshTokenUrl => '$baseUrl/v1/refreshToken';
  static String get uploadUrl => '$baseUrl/v1/upload_obj';
  static String get fileBaseUrl => baseUrl;

  // AES passphrase — matches REACT_APP_AES_KEY / CRYPTO_SECRET in server .env
  // Override at build time: --dart-define=AES_KEY=your_key
  static const String aesKey = String.fromEnvironment(
    'AES_KEY',
    defaultValue: 'D1583ED51EEB8E58F2D3317F4839A',
  );
}
