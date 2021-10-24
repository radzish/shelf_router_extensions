import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

class ShelfExtendedResource {
  const ShelfExtendedResource();
}

class ParameterParsingError {
  final String name;
  final String? value;
  final String? cause;

  ParameterParsingError(this.name, this.value, {this.cause});

  String get message => "parsing parameter '$name'='$value' failed${cause != null ? ": '$cause'" : ''}";
}

class ParameterRequiredError {
  final String name;

  ParameterRequiredError(this.name);

  String get message => "parameter '$name' is required";
}

abstract class SerDeProvider {
  SerDe get serDe;
}

class Param {
  final String? name;

  const Param._({this.name});

  const Param.path({String? name}) : this._(name: name);

  const Param.query({String? name}) : this._(name: name);

  const Param.body() : this._();
}

abstract class SerDe {
  dynamic serialize<T>(T? value);

  T? deserialize<T>(dynamic data);
}

class StandardSerDe implements SerDe {
  @override
  dynamic serialize<T>(T? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }

    throw "unsuported type: ${value.runtimeType}";
  }

  @override
  T? deserialize<T>(dynamic item) {
    if (item == null) {
      return null;
    }
    if (T == String) {
      return item as T;
    }
    if (T == int) {
      if (item is String) {
        return int.parse(item) as T;
      }
      return item as T;
    }
    if (T == double) {
      return double.parse(item) as T;
    }
    if (T == bool) {
      final boolString = item.toString().toLowerCase();
      if (boolString == "true") {
        return true as T;
      }
      if (boolString == "false") {
        return false as T;
      }
      throw "invalid bool value: $boolString";
    }

    throw "unsupported type: ${T}";
  }
}

StandardSerDe standardSerDe = StandardSerDe();

Future<Response> sreInterceptor(Future<Response> Function() resourceMethod) async {
  try {
    return await resourceMethod();
    //TODO: introduce common interface for exceptions
  } on ParameterParsingError catch (e) {
    return Response(HttpStatus.badRequest, body: e.message);
  } on ParameterRequiredError catch (e) {
    return Response(HttpStatus.badRequest, body: e.message);
  } on Response catch (e) {
    return e;
  }
}

T parsePathParam<T>(String name, String value, T Function(String) parser) {
  try {
    return parser(value);
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, cause: e.message);
  }
}

T? parseOptionalSingleQueryParam<T>(String name, Request request, T? Function(dynamic) parser) {
  final uri = request.requestedUri;
  final queryParameter = uri.queryParameters[name];

  if (queryParameter == null) {
    return null;
  }

  return parseRequiredSingleQueryParam(name, request, parser);
}

T parseRequiredSingleQueryParam<T>(String name, Request request, T Function(dynamic) parser) {
  final uri = request.requestedUri;
  final queryParameter = uri.queryParameters[name];

  if (queryParameter == null) {
    throw ParameterRequiredError(name);
  }

  return _doParseValue(name, queryParameter, parser);
}

void _handleDynamicParsingError(e, String name, String? queryParameter) {
  var message;
  try {
    message = e.message;
  } catch (e) {
    // means there is no message property on exception;
  }
  throw ParameterParsingError(name, queryParameter, cause: message ?? e.toString());
}

List<T>? parseOptionalMultiQueryParam<T>(String name, Request request, T? Function(String) parser) {
  final uri = request.requestedUri;
  final queryParameters = uri.queryParametersAll[name];

  if (queryParameters == null) {
    return null;
  }

  return parseRequiredMultiQueryParam(name, request, (val) => parser(val)!);
}

List<T> parseRequiredMultiQueryParam<T>(String name, Request request, T Function(dynamic) parser) {
  final uri = request.requestedUri;
  final queryParameters = uri.queryParametersAll[name];

  if (queryParameters == null || queryParameters.isEmpty) {
    throw ParameterRequiredError(name);
  }

  return queryParameters.map((param) => _doParseValue<T>(name, param, parser)!).toList();
}

T? _doParseValue<T>(String name, dynamic param, Function(dynamic) parser) {
  try {
    return parser(param);
  } catch (e) {
    _handleDynamicParsingError(e, name, param);
  }
}

Future<List<T>?> parseOptionalListBodyParam<T>(String name, Request request, T? Function(dynamic) parser) async {
  final value = await request.readAsString();
  final decodedValues = jsonDecode(value);

  if (!(decodedValues is List)) {
    throw ParameterParsingError(name, value, cause: "value is not List");
  }

  if (decodedValues.isEmpty) {
    return null;
  }

  return parseRequiredListBodyParam(name, request, (val) => parser(val)!);
}

Future<List<T>> parseRequiredListBodyParam<T>(String name, Request request, T Function(dynamic) parser) async {
  final value = await request.readAsString();
  final decodedValues = jsonDecode(value) as List;

  if (decodedValues.isEmpty) {
    throw ParameterRequiredError(name);
  }

  if (!(decodedValues is List)) {
    throw ParameterParsingError(name, value, cause: "value is not List");
  }

  return decodedValues.map(parser).cast<T>().toList();
}

Future<T?> parseOptionalSingleBodyParam<T>(String name, Request request, T? Function(dynamic) parser) async {
  final value = await request.readAsString();

  if (value.isEmpty) {
    return null;
  }

  final decodedValue = _decodeJson(value);

  try {
    return _doParseValue(name, decodedValue, parser);
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, cause: e.message);
  }
}

Future<T> parseRequiredSingleBodyParam<T>(String name, Request request, T Function(dynamic) parser) async {
  final value = await request.readAsString();

  if (value.isEmpty) {
    throw ParameterRequiredError(name);
  }

  final decodedValue = _decodeJson(value);

  try {
    return _doParseValue(name, decodedValue, parser);
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, cause: e.message);
  }
}

Response createResponse<T>(T data, SerDe serDe) {
  if (data is Response) {
    return data;
  }

  final value =
      isType<T, List>() ? (data as List).map((item) => serDe.serialize(item)).toList() : serDe.serialize(data);

  var result;

  if (value != null) {
    if (value is List || value is Map) {
      result = jsonEncode(value);
    } else {
      result = value.toString();
    }
  }

  return Response.ok(result);
}

String encodeData<T>(T data, SerDe serDe) {
  dynamic result = serDe.serialize<T>(data);
  return jsonEncode(result);
}

T? decodeData<T>(dynamic data, SerDe serDe) {
  final json = _decodeJson(data);
  return serDe.deserialize<T>(json);
}

dynamic _decodeJson(String data) {
  dynamic json;
  try {
    json = jsonDecode(data);
    // we are interested in json objects and arrays only.
    // all other types should be in pure string and parsed by deserializer
    if (!(json is Map) && !(json is List)) {
      json = data;
    }
  } catch (e) {
    json = data;
  }
  return json;
}

bool isType<A, B>() {
  return <A>[] is List<B>;
}
