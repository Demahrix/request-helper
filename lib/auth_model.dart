
class AuthModel<R> {

  final R reference;
  final String accessTokens;
  final String refreshToken;

  AuthModel({
    required this.reference,
    required this.accessTokens,
    required this.refreshToken
  });

}
