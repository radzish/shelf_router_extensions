import 'dart:async' show Future;

import 'package:analyzer/dart/element/element.dart' show ClassElement, ElementKind, ExecutableElement;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart' show DartType, InterfaceType, ParameterizedType;
import 'package:build/build.dart' show BuildStep, log;
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as code;
import 'package:code_builder/code_builder.dart';
import 'package:http_methods/http_methods.dart' show isHttpMethod;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_router/src/router_entry.dart' show RouterEntry;
import 'package:shelf_router_extensions/shelf_router_extensions.dart';
import 'package:source_gen/source_gen.dart' as g;

//TODO: make sure that only resources marked with ShelfExtendedResource are handled

final _paramChecker = g.TypeChecker.fromRuntime(Param);
final _listTypeChecker = g.TypeChecker.fromRuntime(List);
final _serDeProviderChecker = g.TypeChecker.fromRuntime(SerDeProvider);
final _nullTypeChecker = g.TypeChecker.fromRuntime(Null);

final RegExp _routeParser = RegExp(r'([^<]*)(?:<([^>|]+)(?:\|([^>]*))?>)?');

// Type checkers that we need later
final _routeType = g.TypeChecker.fromRuntime(shelf_router.Route);
final _routerType = g.TypeChecker.fromRuntime(shelf_router.Router);
final _responseType = g.TypeChecker.fromRuntime(shelf.Response);
final _requestTypeChecker = g.TypeChecker.fromRuntime(shelf.Request);

/// A representation of a handler that was annotated with [Route].
class _Handler {
  final String? verb, route;
  final ExecutableElement element;

  _Handler(this.verb, this.route, this.element);
}

/// Find members of a class annotated with [shelf_router.Route].
List<ExecutableElement> getAnnotatedElementsOrderBySourceOffset(ClassElement cls) {
  return <ExecutableElement>[]
    ..addAll(cls.methods.where(_routeType.hasAnnotationOfExact))
    ..addAll(cls.accessors.where(_routeType.hasAnnotationOfExact))
    ..sort((a, b) => (a.nameOffset ?? -1).compareTo(b.nameOffset ?? -1));
}

/// Generate a `_$<className>Router(<className> service)` method that returns a
/// [shelf_router.Router] configured based on annotated handlers.
code.Method _buildRouterMethod({
  required ClassElement classElement,
  required List<_Handler> handlers,
}) =>
    code.Method(
      (b) => b
        ..name = '_\$${classElement.name}Router'
        ..requiredParameters.add(
          code.Parameter((b) => b
            ..name = 'service'
            ..type = code.refer(classElement.name)),
        )
        ..returns = code.refer('Router')
        ..body = code.Block(
          (b) => b
            ..addExpression(code.refer('Router').newInstance([]).assignFinal('router'))
            ..statements.addAll(handlers.map((h) => _buildAddHandlerCode(
                  classElement: classElement,
                  router: code.refer('router'),
                  service: code.refer('service'),
                  handler: h,
                )))
            ..addExpression(code.refer('router').returned),
        ),
    );

/// Generate the code statement that adds [handler] from [service] to [router].
code.Code _buildAddHandlerCode({
  required ClassElement classElement,
  required code.Reference router,
  required code.Reference service,
  required _Handler handler,
}) {
  switch (handler.verb) {
    case r'$mount':
      return router.property('mount').call([
        code.literalString(handler.route!, raw: true),
        service.property(handler.element.name),
      ]).statement;
    case r'$all':
      return router.property('all').call([
        code.literalString(handler.route!, raw: true),
        service.property(handler.element.name),
      ]).statement;
    default:
      final pathParamNames = _resolvePathParamNames(handler.route!);
      return router.property('add').call([
        code.literalString(handler.verb!.toUpperCase()),
        code.literalString(handler.route!, raw: true),
        Method(
          (b) => b
            ..requiredParameters.addAll(_handlerParameterNames(pathParamNames))
            ..body = code.refer('sreInterceptor').call([
              Method(
                (b1) => b1
                  ..modifier = code.MethodModifier.async
                  ..body = code.Block(
                    (b2) => b2
                      ..addExpression(_createSerDe(classElement))
                      ..addExpression(
                        code
                            .refer(
                                "createResponse<${resolveReturnType(handler).getDisplayString(withNullability: true)}>")
                            .call([
                          service.property(handler.element.name).call(_buildParameters(handler)).awaited,
                          code.refer("serDe"),
                        ]).returned,
                      ),
                  ),
              ).closure
            ]).code,
        ).closure
      ]).statement;
  }
}

List<String> _resolvePathParamNames(String route) {
  List<String> result = [];

  final it = _routeParser.allMatches(route).iterator;
  while (it.moveNext()) {
    final currentMatch = it.current;
    final paramName = currentMatch.group(2);
    if (paramName == null) {
      break;
    }
    result.add(paramName);
  }

  return result;
}

code.Expression _createSerDe(ClassElement classElement) {
  bool isSerDeProvider = _serDeProviderChecker.isAssignableFrom(classElement);
  return code.refer(isSerDeProvider ? "service.serDe" : "standardSerDe").assignFinal("serDe");
}

class ReturnTypeInfo {
  final String name;
  final List<code.Expression> arguments;

  ReturnTypeInfo(this.name, {this.arguments = const []});
}

DartType resolveReturnType(_Handler handler) {
  // return type must be future
  final futureType = handler.element.returnType as InterfaceType;
  return futureType.typeArguments.first;
}

List<Parameter> _handlerParameterNames(List<String> paramNames) {
  return [
    code.Parameter((b) => b
      ..type = code.refer("Request")
      ..name = "request"),
    for (final paramName in paramNames)
      code.Parameter((b) => b
        ..type = code.refer("String")
        ..name = paramName),
  ];
}

List<code.Expression> _buildParameters(_Handler handler) {
  return handler.element.parameters.map(_convertParameter).toList();
}

code.Expression _convertParameter(ParameterElement param) {
  if (_isRequestParam(param)) {
    return code.refer("request");
  }

  final paramMeta = param.metadata.firstWhere(
    (meta) =>
        meta.element is ConstructorElement &&
        _paramChecker.isExactlyType((meta.element as ConstructorElement).returnType),
  );

  final constructorName = (paramMeta.element as ConstructorElement).name;

  final constructorConstant = param.metadata.first.computeConstantValue()!;
  final required = !isNullable(param.type);
  final name = constructorConstant.getField("name")!.toStringValue();

  switch (constructorName) {
    case "path":
      return _buildPathParam(name, param.name, required, param.type);
    case "query":
      return _buildQueryParam(name, param.name, required, param.type);
    case "body":
      return _buildBodyParam(name, param.name, required, param.type);
    default:
      throw "unsuported Param: $constructorName";
  }
}

bool isNullable(DartType type) {
  return type.nullabilitySuffix == NullabilitySuffix.question;
}

code.Expression _buildPathParam(String? name, String paramName, bool required, DartType type) {
  var parseMethodCall = code.Method((b) => b
    ..requiredParameters = ListBuilder(<Parameter>[code.Parameter((b) => b..name = "val")])
    ..body = code.refer("decodeData<${type.name}>").call([code.refer("val"), code.refer("serDe")]).code).closure;

  if (required) {
    parseMethodCall = parseMethodCall.nullChecked;
  }

  return code.refer("parsePathParam").call([
    code.literalString(name ?? paramName),
    code.refer(name ?? paramName),
    parseMethodCall,
  ]);
}

code.Expression _buildQueryParam(String? name, String paramName, bool required, DartType type) {
  final isList = _listTypeChecker.isAssignableFromType(type);
  final listGenerics = (type as InterfaceType).typeArguments;
  final resolvedType = isList ? listGenerics.first : type;

  var parseMethodCall = code.Method((b) => b
        ..requiredParameters = ListBuilder(<Parameter>[
          code.Parameter((b) => b
            ..type = code.refer("dynamic")
            ..name = "val")
        ])
        ..body = code.refer("decodeData<${resolvedType.name}>").call([code.refer("val"), code.refer("serDe")]).code)
      .closure;

  if (required) {
    parseMethodCall = parseMethodCall.nullChecked;
  }

  return code
      .refer(isList
          ? (required ? "parseRequiredMultiQueryParam" : "parseOptionalMultiQueryParam")
          : (required ? "parseRequiredSingleQueryParam" : "parseOptionalSingleQueryParam"))
      .call([
    code.literalString(name ?? paramName),
    code.refer("request"),
    parseMethodCall,
  ]);
}

code.Expression _buildBodyParam(String? name, String paramName, bool required, DartType type) {
  final isList = _listTypeChecker.isAssignableFromType(type);
  DartType resolvedType = type;
  if (isList) {
    final listGenerics = (type as InterfaceType).typeArguments;
    resolvedType = listGenerics.first;
  }

  return code
      .refer(isList
          ? required
              ? "parseRequiredListBodyParam<${resolvedType.displayName}>"
              : "parseOptionalListBodyParam<${resolvedType.displayName}?>"
          : required
              ? "parseRequiredSingleBodyParam<${resolvedType.displayName}>"
              : "parseOptionalSingleBodyParam<${resolvedType.displayName}?>")
      .call([
    code.literalString(name ?? paramName),
    code.refer("request"),
    code.Method((b) {
      var bodyCall = code.refer("serDe.deserialize<${resolvedType.displayName}>").call([code.refer("val")]);
      if (required) {
        bodyCall = bodyCall.nullChecked;
      }
      b
        ..requiredParameters = ListBuilder(<Parameter>[
          code.Parameter((b) => b
            ..type = code.TypeReference((b) => b..symbol = "dynamic")
            ..name = "val")
        ])
        ..body = bodyCall.code;
    }).closure,
  ]).awaited;
}

bool _isRequestParam(ParameterElement param) {
  return _requestTypeChecker.isAssignableFromType(param.type);
}

class ShelfRouterExtensionsGenerator extends g.Generator {
  @override
  Future<String?> generate(g.LibraryReader library, BuildStep step) async {
    // Create a map from ClassElement to list of annotated elements sorted by
    // offset in source code, this is not type checked yet.
    final classes = <ClassElement, List<_Handler>>{};
    for (final cls in library.classes) {
      final elements = getAnnotatedElementsOrderBySourceOffset(cls);
      if (elements.isEmpty) {
        continue;
      }
      log.info('found shelf_router.Route annotations in ${cls.name}');

      classes[cls] = elements
          .map((e) => _routeType.annotationsOfExact(e).map((a) => _Handler(
                a.getField('verb')!.toStringValue(),
                a.getField('route')!.toStringValue(),
                e,
              )))
          .expand((i) => i)
          .toList();
    }
    if (classes.isEmpty) {
      return null; // nothing to do if nothing was annotated
    }

    // Run type check to ensure method and getters have the right signatures.
    //TODO: implement validation
//    for (final handler in classes.values.expand((i) => i)) {
//      // If the verb is $mount, then it's not a handler, but a mount.
//      if (handler.verb.toLowerCase() == r'$mount') {
//        _typeCheckMount(handler);
//      } else {
//        _typeCheckHandler(handler);
//      }
//    }

    // Build library and emit code with all generate methods.
    final methods = classes.entries.map((e) => _buildRouterMethod(
          classElement: e.key,
          handlers: e.value,
        ));
    return code.Library((b) => b.body.addAll(methods)).accept(code.DartEmitter()).toString();
  }
}

/// Type checks for the case where [shelf_router.Route] is used to annotate
/// shelf request handler.
void _typeCheckHandler(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError('The shelf_router.Route annotation cannot be used on static members',
        element: h.element);
  }

  // Check the verb, note that $all is a special value for handling all verbs.
  if (!isHttpMethod(h.verb!) && h.verb != r'$all') {
    throw g.InvalidGenerationSourceError(
        'The verb "${h.verb}" used in shelf_router.Route annotation must be '
        'a valid HTTP method',
        element: h.element);
  }

  // Check that this shouldn't have been annotated with Route.mount
  if (h.element.kind == ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
        'Only the shelf_router.Route.mount annotation can only be used on a '
        'getter, and only if it returns a shelf_router.Router',
        element: h.element);
  }

  // Check that this is indeed a method
  if (h.element.kind != ElementKind.METHOD) {
    throw g.InvalidGenerationSourceError(
        'The shelf_router.Route annotation can only be used on request '
        'handling methods',
        element: h.element);
  }

  // Check the route can parse
  List<String> params;
  try {
    params = RouterEntry(h.verb!, h.route!, () => null).params;
  } on ArgumentError catch (e) {
    throw g.InvalidGenerationSourceError(
      e.toString(),
      element: h.element,
    );
  }

  // Ensure that the first parameter is shelf.Request
  if (h.element.parameters.isEmpty) {
//    throw g.InvalidGenerationSourceError(
//        'The shelf_router.Route annotation can only be used on shelf request '
//        'handlers accept a shelf.Request parameter',
//        element: h.element);
  }
//  for (final p in h.element.parameters) {
//    if (p.isOptional) {
//      TODO: re-implement this check
//      throw g.InvalidGenerationSourceError(
//          'The shelf_router.Route annotation can only be used on shelf '
//          'request handlers accept a shelf.Request parameter and/or a '
//          'shelf.Request parameter and all string parameters in the route, '
//          'optional parameters are not permitted',
//          element: p);
//    }
//  }
//  if (!_requestTypeChecker.isExactlyType(h.element.parameters.first.type)) {
//    throw g.InvalidGenerationSourceError(
//        'The shelf_router.Route annotation can only be used on shelf request '
//        'handlers accept a shelf.Request parameter as first parameter',
//        element: h.element);
//  }
  if (h.element.parameters.length > 1) {
    //TODO: re-implement this check
//    if (h.element.parameters.length != params.length + 1) {
//      throw g.InvalidGenerationSourceError(
//          'The shelf_router.Route annotation can only be used on shelf '
//          'request handlers accept a shelf.Request parameter and/or a '
//          'shelf.Request parameter and all string parameters in the route',
//          element: h.element);
//    }
    for (int i = 0; i < params.length; i++) {
      final p = h.element.parameters[i + 1];
//      if (p.name != params[i]) {
//        throw g.InvalidGenerationSourceError(
//            'The shelf_router.Route annotation can only be used on shelf '
//            'request handlers accept a shelf.Request parameter and/or a '
//            'shelf.Request parameter and all string parameters in the route, '
//            'the "${p.name}" parameter should be named "${params[i]}"',
//            element: p);
//      }
      //TODO: add checks for supported types
//      if (!_stringType.isExactlyType(p.type)) {
//        throw g.InvalidGenerationSourceError(
//            'The shelf_router.Route annotation can only be used on shelf '
//            'request handlers accept a shelf.Request parameter and/or a '
//            'shelf.Request parameter and all string parameters in the route, '
//            'the "${p.name}" parameter is not of type string',
//            element: p);
//      }
    }
  }

  // Check the return value of the method.
  var returnType = h.element.returnType;
  // Unpack Future<T> and FutureOr<T> wrapping of responseType
  if (returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr) {
    returnType = (returnType as ParameterizedType).typeArguments.first;
  }
  if (!_responseType.isAssignableFromType(returnType)) {
    //TODO: add checks for supported types
//    throw g.InvalidGenerationSourceError(
//        'The shelf_router.Route annotation can only be used on shelf request '
//        'handlers that return shelf.Response, Future<shelf.Response> or '
//        'FutureOr<shelf.Response>, and not "${h.element.returnType}"',
//        element: h.element);
  }
}

/// Type checks for the case where [shelf_router.Route.mount] is used to annotate
/// a getter that returns a [shelf_router.Router].
void _typeCheckMount(_Handler h) {
  if (h.element.isStatic) {
    throw g.InvalidGenerationSourceError('The shelf_router.Route annotation cannot be used on static members',
        element: h.element);
  }

  // Check that this should have been annotated with Route.mount
  if (h.element.kind != ElementKind.GETTER) {
    throw g.InvalidGenerationSourceError(
        'The shelf_router.Route.mount annotation can only be used on a '
        'getter that returns shelf_router.Router',
        element: h.element);
  }

  // Sanity checks for the prefix
  if (!h.route!.startsWith('/') || !h.route!.endsWith('/')) {
    throw g.InvalidGenerationSourceError(
        'The prefix "${h.route}" in shelf_router.Route.mount(prefix) '
        'annotation must begin and end with a slash',
        element: h.element);
  }
  if (h.route!.contains('<')) {
    throw g.InvalidGenerationSourceError(
        'The prefix "${h.route}" in shelf_router.Route.mount(prefix) '
        'annotation cannot contain <',
        element: h.element);
  }

  if (!_routerType.isAssignableFromType(h.element.returnType)) {
    throw g.InvalidGenerationSourceError(
        'The shelf_router.Route.mount annotation can only be used on a '
        'getter that returns shelf_router.Router',
        element: h.element);
  }
}
