class Company {
  final String companyId;
  final String companyName;

  const Company({required this.companyId, required this.companyName});

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        companyId: json['company_id'] as String? ?? '',
        companyName: json['company_name'] as String? ?? '',
      );
}

class LoginResponse {
  final String? token;
  final String? refreshToken;
  final String? statusCode;
  final String? message;
  final String? nextStep;
  final String? sessionToken;
  final List<Company>? companies;
  final bool? status;

  const LoginResponse({
    this.token,
    this.refreshToken,
    this.statusCode,
    this.message,
    this.nextStep,
    this.sessionToken,
    this.companies,
    this.status,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String?,
        refreshToken: json['refresh_token'] as String?,
        statusCode: json['status_code'] as String?,
        message: json['message'] as String?,
        nextStep: json['next_step'] as String?,
        sessionToken: json['session_token'] as String?,
        status: json['status'] as bool?,
        companies: (json['companies'] as List<dynamic>?)
            ?.map((e) => Company.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get hasToken => token != null && token!.isNotEmpty;
  bool get needsOtp => nextStep == 'otp';
  bool get needsCompany => nextStep == 'company' && !hasToken;
  bool get isError => status == false;
}
