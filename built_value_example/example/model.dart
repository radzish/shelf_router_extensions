import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'model.g.dart';

abstract class NewsItem<T> implements Built<NewsItem<T>, NewsItemBuilder<T>> {
  NewsItem._();

  factory NewsItem([void Function(NewsItemBuilder<T>) updates]) = _$NewsItem<T>;

  static Serializer<NewsItem> get serializer => _$newsItemSerializer;

  int? get id;

  String? get title;

  T? get category;
}

abstract class Generic implements Built<Generic, GenericBuilder> {
  Generic._();

  factory Generic([void Function(GenericBuilder) updates]) = _$Generic;

  static Serializer<Generic> get serializer => _$genericSerializer;

  String? get value;
}

class MediaType extends EnumClass {
  static Serializer<MediaType> get serializer => _$mediaTypeSerializer;

  static const MediaType image = _$mediaTypeImage;
  static const MediaType youtube = _$mediaTypeYoutube;
  static const MediaType facebook = _$mediaTypeFacebook;

  const MediaType._(String name) : super(name);

  static BuiltSet<MediaType> get values => _$mediaTypeValues;

  static MediaType valueOf(String name) => _$mediaTypeValueOf(name);

  static List<MediaType> get orderedValues => <MediaType>[image, youtube, facebook];
}
