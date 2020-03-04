import 'package:built_collection/built_collection.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';

import 'model.dart';

part 'serializers.g.dart';

@SerializersFor(
  [
    NewsItem,
    Generic,
    MediaType,
  ],
)
final Serializers serializers = (_$serializers.toBuilder()
      ..addPlugin(StandardJsonPlugin())
      ..add(Iso8601DateTimeSerializer())
      ..addBuilderFactory(FullType(NewsItem, [FullType(Generic)]), () => NewsItemBuilder<Generic>())
      ..addBuilderFactory(FullType(NewsItem, [FullType(String)]), () => NewsItemBuilder<String>())
    //
    )
    .build();
