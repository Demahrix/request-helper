import 'dart:async' show FutureOr;
import 'dart:convert' show utf8;
import 'dart:developer';
import 'dart:io' show SocketException;
import 'dart:typed_data' show Uint8List;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:request_helper/auth_data_model.dart';
import 'http_method.dart';


class RequestHelper<R> {

  final String? _baseUrl;
  final String Function()? _baseUrlBuilder;
  final dynamic Function(int statusCode, Uint8List body) _errorBuilder;
  final FutureOr<String> Function() _getToken;
  final Future<AuthDataModel<R>> Function() _fetchRefreshToken;
  final FutureOr<void> Function(AuthDataModel<R>) _saveTokens;
  final bool Function(dynamic error) _isAuthenticateError;
  final void Function(String path, dynamic error)? _onDisconnect;

  final SharedPreferencesAsync _asyncPrefs = SharedPreferencesAsync();

  RequestHelper({
    String? baseUrl,
    String Function()? baseUrlBuilder,
    required dynamic Function(int statusCode, Uint8List body) errorBuilder,
    required FutureOr<String> Function() getToken,
    required Future<AuthDataModel<R>> Function() fetchRefreshToken,
    required FutureOr<void> Function(AuthDataModel<R>) saveTokens,
    required bool Function(dynamic error) isAuthenticateError,
    void Function(String path, dynamic error)? onDisconnect
  }): _baseUrl = baseUrl,
      _baseUrlBuilder = baseUrlBuilder,
      _errorBuilder = errorBuilder,
      _getToken = getToken,
      _fetchRefreshToken = fetchRefreshToken,
      _saveTokens = saveTokens,
      _isAuthenticateError = isAuthenticateError,
      _onDisconnect = onDisconnect,
      assert((baseUrl == null) != (baseUrlBuilder == null));

  static bool ok(int statusCode) => statusCode >= 200 && statusCode <= 299;

  String _getBaseUrl() {
    return _baseUrl ?? _baseUrlBuilder!();
  }

  Future<T> get<T>(String path, {
    Map<String, String>? headers,
    http.Client? client,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    return request(method: HttpMethod.GET, headers: headers, path: path, completeUrl: null, client: client, body: null, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> post<T>(String path, {
    Map<String, String>? headers,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    return request(method: HttpMethod.POST, headers: headers, path: path, completeUrl: null, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> patch<T>(String path, {
    Map<String, String>? headers,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    return request(method: HttpMethod.PATCH, headers: headers, path: path, completeUrl: null, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> put<T>(String path, {
    Map<String, String>? headers,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    return request(method: HttpMethod.PUT, headers: headers, path: path, completeUrl: null, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> delete<T>(String path, {
    Map<String, String>? headers,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    return request(method: HttpMethod.DELETE, headers: headers, path: path, completeUrl: null, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> request<T>({
    required HttpMethod method,
    Map<String, String>? headers,
    String? path,
    String? completeUrl,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) {
    if (includeToken)
      return _handleAccessTokenExpiration<T>(method: method, headers: headers, path: path, completeUrl: completeUrl, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
    return _requestHelper<T>(method: method, headers: headers, path: path, completeUrl: completeUrl, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
  }

  Future<T> _requestHelper<T>({
    required HttpMethod method,
    Map<String, String>? headers,
    String? path,
    String? completeUrl,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) async {

    var fn = switch(method) {
      HttpMethod.POST => client?.post ?? http.post,
      HttpMethod.PUT => client?.put ?? http.put,
      HttpMethod.PATCH => client?.patch ?? http.patch,
      HttpMethod.DELETE => client?.delete ?? http.delete,
      HttpMethod.GET => null
    };

    String? token;

    if (includeToken)
      token = await _getToken();

    Map<String, String> currentHeaders = {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate',
      if (token != null)
        'Authorization': 'Bearer $token',
      if (headers != null)
        ...headers
    };

    var url = completeUrl ?? '${_getBaseUrl()}$path';

    Future<http.Response> future = fn == null
      ? (client?.get ?? http.get)(Uri.parse(url), headers: currentHeaders)
      : fn(Uri.parse(url), headers: currentHeaders, body: body);

    http.Response response;

    try {
      response = await future;
      if (ok(response.statusCode))
        _saveInCache(method, url, response);
    } catch(err) {
      // Uniquement des erreurs de connexion ou de communications au serveurs
      var result = await _getInCache(method, url);
      if (result == null)
        rethrow;
      response = result;
    }

    if (!ok(response.statusCode))
      throw _errorBuilder(response.statusCode, response.bodyBytes);

    return requestParser(response);
  }

  Future<T> _handleAccessTokenExpiration<T>({
    required HttpMethod method,
    Map<String, String>? headers,
    String? path,
    String? completeUrl,
    http.Client? client,
    Object? body,
    bool includeToken = true,
    required T Function(http.Response) requestParser,
    bool cache = false
  }) async {
    try {
      var response = await _requestHelper(method: method, headers: headers, path: path, completeUrl: completeUrl, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
      return response;
    } catch (err) {
      if (!(_isAuthenticateError(err))) // Continue
        rethrow;
    }

    try {
      var authData = await _fetchRefreshToken();
      await _saveTokens(authData);
      log('#####################################################################');
      log('########################## REFRESH TOKEN ############################');
      log('#####################################################################');
      return await _requestHelper(method: method, headers: headers, path: path, completeUrl: completeUrl, client: client, body: body, includeToken: includeToken, requestParser: requestParser, cache: cache);
    } catch(e) {
      if (e is! SocketException)
        _onDisconnect?.call((path ?? completeUrl)!, e);
      rethrow;
    }
  }


  static String _getCacheKey(HttpMethod method, String url) => '${method.name}_#_$url';

  Future<http.Response?> _getInCache(HttpMethod method, String url) async {
    var key = _getCacheKey(method, url);
    var data = await _asyncPrefs.getString(key);
    if (data == null)
      return null;
    return http.Response.bytes(utf8.encode(data), 217, headers: { 'Content-type': 'application/json; charset=utf-8' });
  }

  Future<void> _saveInCache(HttpMethod method, String url, http.Response response) async {
    try {
      var key = _getCacheKey(method, url);
      await _asyncPrefs.setString(key, utf8.decode(response.bodyBytes));
    } catch(err) {}
  }

}
