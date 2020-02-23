// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async' show Future;

import 'package:analyzer/dart/element/element.dart' show ClassElement, ElementKind, ExecutableElement;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart' show DartType, InterfaceType, ParameterizedType;
import 'package:build/build.dart' show BuildStep, log;
import 'package:code_builder/code_builder.dart' as code;
import 'package:code_builder/code_builder.dart';
import 'package:http_methods/http_methods.dart' show isHttpMethod;
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_router/src/router_entry.dart' show RouterEntry;
import 'package:shelf_router_extensions/shelf_router_extensions.dart';
import 'package:source_gen/source_gen.dart' as g;

//TODO: make sure that only resources marked with ShelfExtendedResource are handled

final _queryParamChecker = g.TypeChecker.fromRuntime(QueryParam);
final _listTypeChecker = g.TypeChecker.fromRuntime(List);

// Type checkers that we need later
final _routeType = g.TypeChecker.fromRuntime(shelf_router.Route);
final _routerType = g.TypeChecker.fromRuntime(shelf_router.Router);
final _responseType = g.TypeChecker.fromRuntime(shelf.Response);
final _requestType = g.TypeChecker.fromRuntime(shelf.Request);

/// A representation of a handler that was annotated with [Route].
class _Handler {
  final String verb, route;
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
  @required ClassElement classElement,
  @required List<_Handler> handlers,
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
                  router: code.refer('router'),
                  service: code.refer('service'),
                  handler: h,
                )))
            ..addExpression(code.refer('router').returned),
        ),
    );

/// Generate the code statement that adds [handler] from [service] to [router].
code.Code _buildAddHandlerCode({
  @required code.Reference router,
  @required code.Reference service,
  @required _Handler handler,
}) {
  switch (handler.verb) {
    case r'$mount':
      return router.property('mount').call([
        code.literalString(handler.route, raw: true),
        service.property(handler.element.name),
      ]).statement;
    case r'$all':
      return router.property('all').call([
        code.literalString(handler.route, raw: true),
        service.property(handler.element.name),
      ]).statement;
    default:
      return router.property('add').call([
        code.literalString(handler.verb.toUpperCase()),
        code.literalString(handler.route, raw: true),
        Method(
          (b) => b
            ..requiredParameters.addAll(_handlerParameterNames(handler))
            ..body = code.refer('sreInterceptor').call([
              Method(
                (b) {
                  final returnTypeInfo = resolveReturnTypeInfo(handler.element.returnType);
                  return b
                    ..modifier = code.MethodModifier.async
                    ..body = code.refer(returnTypeInfo.name).call(
                      [
                        service.property(handler.element.name).call(_buildParameters(handler)).awaited,
                        ...returnTypeInfo.arguments,
                      ],
                    ).code;
                },
              ).closure
            ]).code,
        ).closure
      ]).statement;
  }
}

class ReturnTypeInfo {
  final String name;
  final List<code.Expression> arguments;

  ReturnTypeInfo(this.name, {this.arguments = const []});
}

ReturnTypeInfo resolveReturnTypeInfo(DartType returnType) {
  // return type must be future
  final futureType = returnType as InterfaceType;
  final type = futureType.typeArguments.first;

  if (_responseType.isExactlyType(type)) {
    return ReturnTypeInfo('createResponseResponse');
  }

  if (_isBuiltValue(type)) {
    //TODO: change implementation to mixin or interface, which must provide builtSerializers method
    return ReturnTypeInfo(
      'createItemResponse<${type.displayName}>',
      arguments: [
        Method((b) => b
          ..requiredParameters.add(code.Parameter((p) => p..name = 'value'))
          ..body = code.refer('serializeBuiltValue').call(
            [
              code.refer('service.builtSerializers'),
              code.refer('value'),
            ],
          ).code).closure,
      ],
    );
  }

  if (_listTypeChecker.isAssignableFromType(type)) {
    final iterableGenerics = (type as InterfaceType).typeArguments;
    final iterableGenericType = iterableGenerics.first;
    final iterableGenericName = iterableGenericType.isDynamic ? "String" : iterableGenericType.displayName;

    return ReturnTypeInfo(
      'createListResponse<${iterableGenericName}>',
      arguments: [
        Method((b) => b
          ..requiredParameters.add(code.Parameter((p) => p..name = 'value'))
          ..body = code.refer('serializeBuiltValue').call(
            [
              code.refer('service.builtSerializers'),
              code.refer('value'),
            ],
          ).code).closure,
      ],
    );
  }

  throw "Unsupported return type ${type.displayName}";
}

bool _isBuiltValue(DartType type) {
  if (type.element is! ClassElement) return false;
  return (type.element as ClassElement).allSupertypes.any((interfaceType) => interfaceType.name == 'Built');
}

List<Parameter> _handlerParameterNames(_Handler handler) {
  //TODO change type checking against Request to typeChecker
  return handler.element.parameters
      .where((p) => !_isQueryParam(p))
      .map((p) => code.Parameter((b) => b
        ..name = p.name
        ..type = code.refer(p.type.element.displayName == 'Request' ? p.type.element.displayName : 'String')))
      .toList();
}

bool _isQueryParam(ParameterElement p) {
  return _queryParamChecker.hasAnnotationOfExact(p);
}

List<code.Expression> _buildParameters(_Handler handler) {
  return handler.element.parameters.map(_convertParameter).toList();
}

code.Expression _convertParameter(ParameterElement parameter) {
  if (_isQueryParam(parameter)) {
    return _convertQueryParam(parameter);
  } else {
    return _convertPathParam(parameter);
  }
}

code.Expression _convertQueryParam(ParameterElement parameter) {
  final queryParamAnnotation = _queryParamChecker.firstAnnotationOf(parameter);
  final queryParamName = queryParamAnnotation.getField('name').toStringValue() ?? parameter.name;
  final required = queryParamAnnotation.getField('required').toBoolValue();

  var primitiveParseFunction = _resolvePrimitiveParam(parameter.type);

  // primitive
  if (primitiveParseFunction != null) {
    return code.refer(primitiveParseFunction).call(
      [
        code.literalString(queryParamName),
        _wrapWithRequestParamResolve(queryParamName),
        code.literalBool(required),
      ],
    );
  }

  // list
  if (_listTypeChecker.isAssignableFromType(parameter.type)) {
//    parseIterableParam<int>('multiple', request, (val) => parseIntParam('multiple', val), true),

    final iterableGenerics = (parameter.type as InterfaceType).typeArguments;
    final iterableGenericType = iterableGenerics.first;
    final iterableGenericName = iterableGenericType.isDynamic ? "String" : iterableGenericType.displayName;
    primitiveParseFunction =
        iterableGenericType.isDynamic ? "parseStringParam" : _resolvePrimitiveParam(iterableGenericType);

    return code.refer('parseListParam<$iterableGenericName>').call(
      [
        code.literalString(queryParamName),
        code.refer('request'),
        Method((b) => b
          ..requiredParameters.add(code.Parameter((b) => b..name = 'val'))
          ..body = code.refer(primitiveParseFunction).call(
            [
              code.literalString(queryParamName),
              code.refer('val'),
            ],
          ).code).closure,
        code.literalBool(required),
      ],
    );
  }

  throw 'Unsupported type ${parameter.type} of parameter ${parameter.name}';
}

String _resolvePrimitiveParam(DartType parameterType) {
  if (parameterType.isDartCoreString) {
    return 'parseStringParam';
  } else if (parameterType.isDartCoreInt) {
    return 'parseIntParam';
  } else if (parameterType.isDartCoreDouble) {
    return 'parseDoubleParam';
  } else if (parameterType.isDartCoreNum) {
    return 'parseNumParam';
  }
  return null;
}

code.Expression _wrapWithRequestParamResolve(String queryParamName) {
  return code.refer('resolveQueryParam').call([
    code.refer('request'),
    code.literalString(queryParamName),
  ]);
}

code.Expression _convertPathParam(ParameterElement parameter) {
  if (parameter.type.element.displayName == 'Request') {
    return code.refer(parameter.name);
  }

  if (parameter.type.isDartCoreString) {
    return code.refer(parameter.name);
  }

  if (parameter.type.isDartCoreInt) {
    return code.refer('parseIntParam').call([code.literalString(parameter.name), code.refer(parameter.name)]);
  }

  throw 'Unsupported type ${parameter.type} of parameter ${parameter.name}';
}

class ShelfRouterExtensionsGenerator extends g.Generator {
  @override
  Future<String> generate(g.LibraryReader library, BuildStep step) async {
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
                a.getField('verb').toStringValue(),
                a.getField('route').toStringValue(),
                e,
              )))
          .expand((i) => i)
          .toList();
    }
    if (classes.isEmpty) {
      return null; // nothing to do if nothing was annotated
    }

    // Run type check to ensure method and getters have the right signatures.
    for (final handler in classes.values.expand((i) => i)) {
      // If the verb is $mount, then it's not a handler, but a mount.
      if (handler.verb.toLowerCase() == r'$mount') {
        _typeCheckMount(handler);
      } else {
        _typeCheckHandler(handler);
      }
    }

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
  if (!isHttpMethod(h.verb) && h.verb != r'$all') {
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
    params = RouterEntry(h.verb, h.route, () => null).params;
  } on ArgumentError catch (e) {
    throw g.InvalidGenerationSourceError(
      e.toString(),
      element: h.element,
    );
  }

  // Ensure that the first parameter is shelf.Request
  if (h.element.parameters.isEmpty) {
    throw g.InvalidGenerationSourceError(
        'The shelf_router.Route annotation can only be used on shelf request '
        'handlers accept a shelf.Request parameter',
        element: h.element);
  }
  for (final p in h.element.parameters) {
    if (p.isOptional) {
      //TODO: re-implement this check
//      throw g.InvalidGenerationSourceError(
//          'The shelf_router.Route annotation can only be used on shelf '
//          'request handlers accept a shelf.Request parameter and/or a '
//          'shelf.Request parameter and all string parameters in the route, '
//          'optional parameters are not permitted',
//          element: p);
    }
  }
  if (!_requestType.isExactlyType(h.element.parameters.first.type)) {
    throw g.InvalidGenerationSourceError(
        'The shelf_router.Route annotation can only be used on shelf request '
        'handlers accept a shelf.Request parameter as first parameter',
        element: h.element);
  }
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
      if (p.name != params[i]) {
        throw g.InvalidGenerationSourceError(
            'The shelf_router.Route annotation can only be used on shelf '
            'request handlers accept a shelf.Request parameter and/or a '
            'shelf.Request parameter and all string parameters in the route, '
            'the "${p.name}" parameter should be named "${params[i]}"',
            element: p);
      }
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
  if (!h.route.startsWith('/') || !h.route.endsWith('/')) {
    throw g.InvalidGenerationSourceError(
        'The prefix "${h.route}" in shelf_router.Route.mount(prefix) '
        'annotation must begin and end with a slash',
        element: h.element);
  }
  if (h.route.contains('<')) {
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
