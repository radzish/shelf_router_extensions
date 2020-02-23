// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_router_extensions_generator_example.dart';

// **************************************************************************
// ShelfRouterExtensionsGenerator
// **************************************************************************

Router _$ResourceRouter(Resource service) {
  final router = Router();
  router.add(
      'GET',
      r'/test-route/<sParam>/<iParam>',
      (Request request, String sParam, String iParam) => sreInterceptor(
          () async => createListResponse<String>(
              await service.testGet(
                  request,
                  sParam,
                  parseIntParam('iParam', iParam),
                  parseStringParam(
                      'query', resolveQueryParam(request, 'query'), true),
                  parseIntParam(
                      'reqnum', resolveQueryParam(request, 'reqnum'), true),
                  parseIntParam(
                      'num', resolveQueryParam(request, 'num'), false),
                  parseIntParam(
                      'noname', resolveQueryParam(request, 'noname'), true),
                  parseListParam<int>('multiple', request,
                      (val) => parseIntParam('multiple', val), true),
                  parseListParam<String>('multipleStrings', request,
                      (val) => parseStringParam('multipleStrings', val), true)),
              (value) =>
                  serializeBuiltValue(service.builtSerializers, value))));
  return router;
}
