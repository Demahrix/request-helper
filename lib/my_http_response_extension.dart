import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, json;

extension MyHttpResponseExtension on http.Response {

  dynamic toJson() {
    return json.decode(utf8.decode(bodyBytes));
  }

}
