import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'model.g.dart';

abstract class NewsItem implements Built<NewsItem, NewsItemBuilder> {
  NewsItem._();

  factory NewsItem([void Function(NewsItemBuilder) updates]) = _$NewsItem;

  static Serializer<NewsItem> get serializer => _$newsItemSerializer;

  int get id;

  String get title;
}
