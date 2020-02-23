import 'dart:convert';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
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

class QueryParam {
  final String name;
  final bool required;

  const QueryParam({this.name, this.required = true});
}

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

String parseStringParam(String name, String value, [bool required = true]) {
  return _parseParam(name, value, (val) => val, required);
}

int parseIntParam(String name, String value, [bool required = true]) {
  return _parseParam(name, value, (val) => int.parse(val), required);
}

double parseDoubleParam(String name, String value, [bool required = true]) {
  return _parseParam(name, value, (val) => double.parse(val), required);
}

num parseNumParam(String name, String value, [bool required = true]) {
  return _parseParam(name, value, (val) => num.parse(val), required);
}

List<T> parseListParam<T>(String name, Request request, T Function(String) parser, bool required) {
  final uri = request.requestedUri;
  final queryParameters = uri.queryParametersAll[name];

  if (required && queryParameters == null) {
    throw ParameterRequiredError(name);
  }

  return queryParameters.map(parser).toList();
}

T _parseParam<T>(String name, String value, T Function(String) parser, bool required) {
  if (required && value == null) {
    throw ParameterRequiredError(name);
  }

  if (value == null) {
    return null;
  }

  try {
    return parser(value);
  } on FormatException catch (e) {
    throw ParameterParsingError(name, value, e.message);
  }
}

String resolveQueryParam(Request request, String name) {
  final uri = request.requestedUri;
  return uri.queryParameters[name];
}

Response createResponseResponse(Response response) => response;

Response createItemResponse<T>(T item, dynamic Function(T) serializer) {
  final json = serializer(item);
  return Response.ok(jsonEncode(json));
}

Response createListResponse<T>(List<T> value, dynamic Function(T) serializer) {
  final serializedObjects = value.map(serializer).toList();
  return Response.ok(jsonEncode(serializedObjects));
}

dynamic serializeBuiltValue<T extends Built<T, B>, B extends Builder<T, B>>(
  Serializers serializers,
  Built<T, B> result,
) {
  return serializers.serialize(result, specifiedType: FullType(T));
}

//Future<Response> serializeListOfBuiltValues<T extends Built<T, B>, B extends Builder<T, B>>(
//  Serializers serializers,
//  Future<List<Built<T, B>>> result,
//) async {
//  final responseObjects = await result;
//  final serializedObjects =
//      responseObjects.map((responseObject) => serializers.serialize(responseObject, specifiedType: FullType(T))).toList();
//  return Response.ok(jsonEncode(serializedObjects));
//}
