import 'package:built_value/serializer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_router_extensions/shelf_router_extensions.dart';

import 'model.dart';
import 'serializers.dart';

part 'shelf_router_extensions_generator_example.g.dart';

@ShelfExtendedResource()
class Resource with BuiltValueSerDeProvider {
  @Route.get('/test-route/<sParam>/<iParam>')
  Future<NewsItem<Generic>> testGet(
    Request request,
    @Param.path(name: "iParam") int pathParamWithDifferentName,
    @Param.path() String sParam,
    @Param.query(name: 'query') String qsParam,
    @Param.query(name: 'reqnum') int reqQiParam,
    @Param.query(name: 'num') int? qiParam,
    @Param.query() int noname,
    @Param.query() List<int> multiple,
    @Param.query() List<String>? multipleStrings,
//    @Param.body(required: false) List<String> bodyParam,
//    @Param.body(required: false) String bodyParam,
    @Param.body() NewsItem<Generic>? bodyParam,
//  @Param.body(required: false) int bodyParam,
  ) async {
    print(
        'hi $sParam $pathParamWithDifferentName $qsParam $reqQiParam $qiParam $noname $multiple $multipleStrings $bodyParam');

//    return Response.ok("aaa");

    return NewsItem<Generic>((b) => b
      ..id = 777
      ..title = "this is title"
      ..category = Generic((b) => b..value = "aaalll"));

//    return [
//      NewsItem((b) => b
//        ..id = 777
//        ..title = "this is title"),
//      NewsItem((b) => b
//        ..id = 888
//        ..title = "this is title yoyo"),
//    ];
  }

  @Route.get('/test-void')
  Future<void> testVoid() async {
    print("test void");
  }

  @Route.post('/test-body-string-list')
  Future<void> testBodyStringList(@Param.body() List<String> values) async {
    print(values);
  }

  @Route.post('/test-body-int-list')
  Future<void> testBodyIntList(@Param.body() List<int> values) async {
    print(values);
  }

  @Route.get('/test')
  Future<int> test() async {
    return 100500;
  }

  @Route.get('/test-invalid-enum')
  Future<void> testInvalidEnum(@Param.query() MediaType type) async {}

  @Route.get('/test-invalid-enum')
  Future<String?> testNullableReturn() async {}

//  @Route.post('/test-udpate/<id>')
//  Future<Response> testPost(
//      Request request,
//      String sParam,
//      int iParam,
//      @QueryParam(name: 'query') String qsParam,
//      @QueryParam(name: 'reqnum') int reqQiParam,
//      @QueryParam(name: 'num', required: false) int qiParam,
//      @QueryParam() int noname,
//      @QueryParam() List<int> multiple,
//      @QueryParam() List<String> multipleStrings,
//      ) async {
//    return Response.ok('hi $sParam $iParam $qsParam $reqQiParam $qiParam $noname $multiple $multipleStrings');
//  }

  Handler get handler => _$ResourceRouter(this);
}

mixin BuiltValueSerDeProvider implements SerDeProvider {
  SerDe get serDe => BuiltValueSerDe();
}

class BuiltValueSerDe extends StandardSerDe {
  dynamic serialize<T>(T? item) {
    if (item is NewsItem<Generic>) {
      return serializers.serialize(item, specifiedType: FullType(NewsItem, [FullType(Generic)]));
    }
    if (item is NewsItem<String>) {
      return serializers.serialize(item, specifiedType: FullType(NewsItem, [FullType(String)]));
    }
    if (item is MediaType) {
      return serializers.serialize(item, specifiedType: FullType(MediaType));
    }

    return super.serialize<T>(item);
  }

  T? deserialize<T>(dynamic data) {
    if (isType<T, NewsItem<Generic>>()) {
      return serializers.deserialize(data as Object, specifiedType: FullType(NewsItem, [FullType(Generic)])) as T;
    }

    if (isType<T, NewsItem<String>>()) {
      return serializers.deserialize(data as Object, specifiedType: FullType(NewsItem, [FullType(String)])) as T;
    }

    if (T == MediaType) {
      return serializers.deserialize(data as Object, specifiedType: FullType(MediaType)) as T;
    }

    return super.deserialize<T>(data);
  }

  @Route.get('/response')
  Future<Response> testResponse() async {
    return Response.ok(null);
  }

}

void main() async {
  final resource = Resource();

  final handler = Pipeline().addMiddleware(apiContentTypeMiddleware).addHandler(resource.handler);

  final server = await serve(handler, 'localhost', 8888);
  print('Server running on localhost:${server.port}');
}

Middleware apiContentTypeMiddleware = (handler) => (request) async {
      Response response = await handler(request);
      response = response.change(headers: {"content-type": "application/json; charset=utf-8"});
      return response;
    };
