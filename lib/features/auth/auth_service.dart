import '../../core/models/auth_models.dart';
import '../../core/network/graphql_client.dart';

const _loginMutation = '''
mutation Login(\$input: loginInput!) {
  login(input: \$input) {
    token
    refresh_token
    status
    status_code
    message
    next_step
    session_token
    companies {
      company_id
      company_name
    }
  }
}
''';

class AuthService {
  AuthService._();

  static Future<LoginResponse> _login(Map<String, dynamic> input) async {
    final data = await GraphQLService.call(
      _loginMutation,
      variables: {'input': input},
    );
    final login = data['login'] as Map<String, dynamic>?;
    if (login == null) throw const GqlException('Invalid server response.');
    return LoginResponse.fromJson(login);
  }

  static Future<LoginResponse> validate({
    required String email,
    required String password,
    required String deviceId,
  }) =>
      _login({
        'email': email,
        'password': password,
        'device_id': deviceId,
        'step': 'validate',
      });

  static Future<LoginResponse> signinWithOtp({
    required String email,
    required String deviceId,
  }) =>
      _login({
        'email': email,
        'device_id': deviceId,
        'step': 'signin_with_otp',
      });

  static Future<LoginResponse> verifyOtp({
    required String email,
    required String code,
    required String deviceId,
    bool trustDevice = false,
    String? sessionToken,
  }) =>
      _login({
        'email': email,
        'code': code,
        'device_id': deviceId,
        'step': 'otp',
        'trust_device': trustDevice,
        if (sessionToken != null) 'session_token': sessionToken,
      });

  static Future<LoginResponse> selectCompany({
    required String email,
    required String companyId,
    required String sessionToken,
    required String deviceId,
  }) =>
      _login({
        'email': email,
        'company_id': companyId,
        'session_token': sessionToken,
        'device_id': deviceId,
        'step': 'company',
      });
}
