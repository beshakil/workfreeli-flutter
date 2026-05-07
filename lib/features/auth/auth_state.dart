import '../../core/models/auth_models.dart';

enum AuthStep {
  loading,
  unauthenticated,
  otpPending,
  companyPending,
  authenticated,
}

class AuthState {
  final AuthStep step;
  final String? email;
  final String? sessionToken;
  final List<Company>? companies;
  final String? error;
  final bool isLoading;

  const AuthState({
    required this.step,
    this.email,
    this.sessionToken,
    this.companies,
    this.error,
    this.isLoading = false,
  });

  const AuthState.loading()
      : step = AuthStep.loading,
        email = null,
        sessionToken = null,
        companies = null,
        error = null,
        isLoading = false;

  const AuthState.unauthenticated()
      : step = AuthStep.unauthenticated,
        email = null,
        sessionToken = null,
        companies = null,
        error = null,
        isLoading = false;

  const AuthState.authenticated()
      : step = AuthStep.authenticated,
        email = null,
        sessionToken = null,
        companies = null,
        error = null,
        isLoading = false;

  AuthState copyWith({
    AuthStep? step,
    String? email,
    String? sessionToken,
    List<Company>? companies,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return AuthState(
      step: step ?? this.step,
      email: email ?? this.email,
      sessionToken: sessionToken ?? this.sessionToken,
      companies: companies ?? this.companies,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
