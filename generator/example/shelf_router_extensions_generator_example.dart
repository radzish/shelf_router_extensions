import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_router_extensions/shelf_router_extensions.dart';

import 'model.dart';
import 'serializers.dart';

part 'shelf_router_extensions_generator_example.g.dart';

@ShelfExtendedResource()
class Resource {
  @Route.get('/test-route/<sParam>/<iParam>')
  Future<List<String>> testGet(
    Request request,
    String sParam,
    int iParam,
    @QueryParam(name: 'query') String qsParam,
    @QueryParam(name: 'reqnum') int reqQiParam,
    @QueryParam(name: 'num', required: false) int qiParam,
    @QueryParam() int noname,
    @QueryParam() List<int> multiple,
    @QueryParam() List<String> multipleStrings,
  ) async {
    print('hi $sParam $iParam $qsParam $reqQiParam $qiParam $noname $multiple $multipleStrings');

//    return Response.ok("aaa");

//    return NewsItem((b) => b
//      ..id = 777
//      ..title = "this is title");

//    return [
//      NewsItem((b) => b
//        ..id = 777
//        ..title = "this is title"),
//      NewsItem((b) => b
//        ..id = 888
//        ..title = "this is title yoyo"),
//    ];

    return ["aaa", "bbb"];

  }

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

  Handler get handler => _$ResourceRouter(this).handler;

  Serializers get builtSerializers => serializers;
}

void main() async {
  final resource = Resource();

  final handler = Pipeline().addMiddleware(apiContentTypeMiddleware).addHandler(resource.handler);

  final server = await serve(handler, 'localhost', 8080);
  print('Server running on localhost:${server.port}');
}

Middleware apiContentTypeMiddleware = (handler) => (request) async {
      Response response = await handler(request);
      response = response.change(headers: {"content-type": "application/json; charset=utf-8"});
      return response;
    };
