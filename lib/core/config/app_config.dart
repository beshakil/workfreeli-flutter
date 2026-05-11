class AppConfig {
  AppConfig._();

  static const String _serverBase = 'https://cadevapicdn02.freeli.io';

  // Override at build time: --dart-define=API_BASE=https://your-domain.com
  static const String _envBase =
      String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl => _envBase.isNotEmpty ? _envBase : _serverBase;
  static String get graphqlUrl => '$baseUrl/workfreeli';
  static String get refreshTokenUrl => '$baseUrl/v1/refreshToken';
  static String get uploadUrl => '$baseUrl/v1/upload_obj';
  static String get fileBaseUrl => baseUrl;
  static String get xmppRegisterUrl => '$baseUrl/v1/xmpp_register_user';

  // XMPP server domain — override at build time: --dart-define=XMPP_DOMAIN=yourdomain.com
  // Defaults to same host as API server (ejabberd runs alongside the API).
  static const String xmppDomain = String.fromEnvironment(
    'XMPP_DOMAIN',
    defaultValue: 'caquecdn02.freeli.io',
  );

  // ws:// for dev (cleartext), wss:// for production
  // Override: --dart-define=XMPP_WS_URL=wss://yourdomain.com:5443/ws
  static const String _xmppWsOverride = String.fromEnvironment(
    'XMPP_WS_URL',
    defaultValue: '',
  );
  static String get xmppWsUrl =>
      _xmppWsOverride.isNotEmpty ? _xmppWsOverride : 'wss://$xmppDomain:5443/ws';

  // AES passphrase — matches REACT_APP_AES_KEY / CRYPTO_SECRET in server .env
  // Override at build time: --dart-define=AES_KEY=your_key
  static const String aesKey = String.fromEnvironment(
    'AES_KEY',
    defaultValue: 'D1583ED51EEB8E58F2D3317F4839A',
  );
}
