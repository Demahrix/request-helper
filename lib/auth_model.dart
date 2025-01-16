
class AuthModel<R> {

  final R reference;
  final String accessToken;
  final String refreshToken;

  AuthModel({
    required this.reference,
    required this.accessToken,
    required this.refreshToken
  });

  Map<String, dynamic> toMap() => {
    'reference': reference,
    'accessToken': accessToken,
    'refreshToken': refreshToken
  };

}
