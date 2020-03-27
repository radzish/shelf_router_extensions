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
      (Request request, String sParam, String iParam) =>
          sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<NewsItem<Generic>>(
                await service.testGet(
                    request,
                    parsePathParam(
                        'iParam', iParam, (val) => decodeData<int>(val, serDe)),
                    parsePathParam('sParam', sParam,
                        (val) => decodeData<String>(val, serDe)),
                    parseSingleQueryParam('query', request,
                        (val) => decodeData<String>(val, serDe), true),
                    parseSingleQueryParam('reqnum', request,
                        (val) => decodeData<int>(val, serDe), true),
                    parseSingleQueryParam('num', request,
                        (val) => decodeData<int>(val, serDe), false),
                    parseSingleQueryParam('noname', request,
                        (val) => decodeData<int>(val, serDe), true),
                    parseMultiQueryParam('multiple', request,
                        (val) => decodeData<int>(val, serDe), true),
                    parseMultiQueryParam('multipleStrings', request,
                        (val) => decodeData<String>(val, serDe), true),
                    await parseSingleBodyParam<NewsItem<Generic>>(
                        'bodyParam',
                        request,
                        (dynamic val) =>
                            serDe.deserialize<NewsItem<Generic>>(val),
                        false)),
                serDe);
          }));
  router.add(
      'GET',
      r'/test-void',
      (Request request) => sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<void>(await service.testVoid(), serDe);
          }));
  router.add(
      'POST',
      r'/test-body-string-list',
      (Request request) => sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<void>(
                await service.testBodyStringList(
                    await parseListBodyParam<String>('values', request,
                        (dynamic val) => serDe.deserialize<String>(val), true)),
                serDe);
          }));
  router.add(
      'POST',
      r'/test-body-int-list',
      (Request request) => sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<void>(
                await service.testBodyIntList(await parseListBodyParam<int>(
                    'values',
                    request,
                    (dynamic val) => serDe.deserialize<int>(val),
                    true)),
                serDe);
          }));
  router.add(
      'GET',
      r'/test',
      (Request request) => sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<int>(await service.test(), serDe);
          }));
  router.add(
      'GET',
      r'/test-invalid-enum',
      (Request request) => sreInterceptor(() async {
            final serDe = service.serDe;
            return createResponse<void>(
                await service.testInvalidEnum(parseSingleQueryParam('type',
                    request, (val) => decodeData<MediaType>(val, serDe), true)),
                serDe);
          }));
  return router;
}
