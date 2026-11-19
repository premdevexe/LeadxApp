/// Production API and real-time configuration for LeadX.
///
/// Production endpoints are fixed to the official LeadX server and
/// are not editable within the app.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl =
      'https://leadx.cloudaspiresolutions.in/api/v1';

  /// Reverb websocket host/port for real-time.
  static const String defaultReverbHost = 'leadx.cloudaspiresolutions.in';
  static const int defaultReverbPort = 443;
  static const String defaultReverbKey = 'QcK9STacr/NFbZiRmZCNiQ==';

  static Future<String> baseUrl() async => defaultBaseUrl;

  static Future<String> reverbHost() async => defaultReverbHost;

  static Future<int> reverbPort() async => defaultReverbPort;
}

