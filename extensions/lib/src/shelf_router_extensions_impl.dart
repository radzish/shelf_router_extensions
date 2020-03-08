import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

class ShelfExtendedResource {
  const ShelfExtendedResource();
}

class ParameterParsingError {
  final String name;
  final String value;
  final String cause;

  ParameterParsingError(this.name, this.value, this.cause);

  String get message => "parsing parameter '$name'='$value' failed: '$cause'";
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
  final String name;
  final bool required;

  const Param._({this.name, this.required});

  const Param.path({String name}) : this._(name: name, required: true);

  const Param.query({String name, bool required = true}) : this._(name: name, required: required);

  const Param.body({bool required = true}) : this._(required: required);
}

abstract class SerDe {
  dynamic serialize<T>(T value);

  T deserialize<T>(dynamic data);
}

class StandardSerDe implements SerDe {
  @override
  dynamic serialize<T>(T value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }

    throw "unsuported type: ${value.runtimeType}";
  }

  @override
  T deserialize<T>(dynamic item) {
    if (item == null) {
      return null;
    }
    if (T == String) {
      return item as T;
    }
    if (T == int) {
      return int.parse(item) as T;
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
  }
}

T parsePathParam<T>(String name, String value, T Function(String) parser) {
  if (value == null) {
    return null;
  }

  try {
    return parser(value);
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, e.message);
  }
}

T parseSingleQueryParam<T>(String name, Request request, T Function(String) parser, bool required) {
  final uri = request.requestedUri;
  final queryParameter = uri.queryParameters[name];

  if (required && queryParameter == null) {
    throw ParameterRequiredError(name);
  }

  try {
    return queryParameter != null ? parser(queryParameter) : null;
  } catch (e) {
    throw ParameterParsingError(name, queryParameter, e.message);
  }
}

List<T> parseMultiQueryParam<T>(String name, Request request, T Function(String) parser, bool required) {
  final uri = request.requestedUri;
  final queryParameters = uri.queryParametersAll[name];

  if (required && queryParameters == null) {
    throw ParameterRequiredError(name);
  }

  return queryParameters?.map(
    (param) {
      try {
        return parser(param);
      } catch (e) {
        throw ParameterParsingError(name, param, e.message);
      }
    },
  )?.toList();
}

Future<List<T>> parseListBodyParam<T>(String name, Request request, T Function(dynamic) parser, bool required) async {
  final value = await request.readAsString();
  final decodedValues = jsonDecode(value);

  if (!(decodedValues is List)) {
    throw ParameterParsingError(name, value, "value is not List");
  }

  if (required && (decodedValues == null || decodedValues.isEmpty)) {
    throw ParameterRequiredError(name);
  }

  return decodedValues?.map(parser)?.toList()?.toList();
}

Future<T> parseSingleBodyParam<T>(String name, Request request, T Function(dynamic) parser, bool required) async {
  final value = await request.readAsString();

  if (required && (value == null || value.isEmpty)) {
    throw ParameterRequiredError(name);
  }

  if (value == null || value.isEmpty) {
    return null;
  }

  final decodedValue = _decodeJson(value);

  try {
    return decodedValue != null ? parser(decodedValue) : null;
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, e.message);
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

T decodeData<T>(String data, SerDe serDe) {
  final json = _decodeJson(data);
  return serDe.deserialize(json);
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
