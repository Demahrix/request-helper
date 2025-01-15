import 'package:http/http.dart' as http;
import 'package:request_helper/my_http_response_extension.dart';


class RequestParser {

  RequestParser._();

  static http.Response none(http.Response response) => response;

  static T Function(http.Response response) oneOf<T>(T Function(dynamic data) builder) => (http.Response response) => builder(response.toJson());

  static List<T> Function(http.Response response) manyOf<T>(T Function(dynamic data) builder) => ((http.Response response) {
    List data = response.toJson();
    return List.generate(data.length, (index) => builder(data[index]), growable: false);
  });

}
