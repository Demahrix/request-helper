
class AuthDataModel<R> {

  final R reference;
  final String accessToken;
  final String refreshToken;

  AuthDataModel({
    required this.reference,
    required this.accessToken,
    required this.refreshToken
  });

  factory AuthDataModel.fromJson(Map<String, dynamic> data) {
    return AuthDataModel(reference: data['reference'], accessToken: data['accessToken'], refreshToken: data['refreshToken']);
  }

  Map<String, dynamic> toMap() => {
    'reference': reference,
    'accessToken': accessToken,
    'refreshToken': refreshToken
  };

  AuthDataModel<R> merge({ String? refreshToken, String? accessToken }) {
    return AuthDataModel(
      reference: reference,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken
    );
  }

}
