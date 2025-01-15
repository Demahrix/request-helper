

```dart
static final _helper = RequestHelper<int>(
    baseUrl: BASE_URL,
    errorBuilder: (statusCode, data) => HttpError.parse(statusCode, data),
    getToken: () => locator.get<AuthData>().accessToken,
    fetchRefreshToken: () => throw UnimplementedError(),
    saveTokens: (data) {
      locator.update(data);
    },
    isAuthenticateError: (err) => err is HttpError && err.statusCode == 401,
    onDisconnect: (_, __) {

    }
);

_helper.get(
  '/api/v1/customers',
  requestParser: RequestParser.oneOf((data) => PaginatedData.fromJson(data, (e) => CustomerModel.fromJson(e)))
);
```