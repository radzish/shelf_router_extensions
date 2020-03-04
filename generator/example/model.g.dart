// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const MediaType _$mediaTypeImage = const MediaType._('image');
const MediaType _$mediaTypeYoutube = const MediaType._('youtube');
const MediaType _$mediaTypeFacebook = const MediaType._('facebook');

MediaType _$mediaTypeValueOf(String name) {
  switch (name) {
    case 'image':
      return _$mediaTypeImage;
    case 'youtube':
      return _$mediaTypeYoutube;
    case 'facebook':
      return _$mediaTypeFacebook;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<MediaType> _$mediaTypeValues =
    new BuiltSet<MediaType>(const <MediaType>[
  _$mediaTypeImage,
  _$mediaTypeYoutube,
  _$mediaTypeFacebook,
]);

Serializer<NewsItem> _$newsItemSerializer = new _$NewsItemSerializer();
Serializer<Generic> _$genericSerializer = new _$GenericSerializer();
Serializer<MediaType> _$mediaTypeSerializer = new _$MediaTypeSerializer();

class _$NewsItemSerializer implements StructuredSerializer<NewsItem> {
  @override
  final Iterable<Type> types = const [NewsItem, _$NewsItem];
  @override
  final String wireName = 'NewsItem';

  @override
  Iterable<Object> serialize(Serializers serializers, NewsItem object,
      {FullType specifiedType = FullType.unspecified}) {
    final isUnderspecified =
        specifiedType.isUnspecified || specifiedType.parameters.isEmpty;
    if (!isUnderspecified) serializers.expectBuilder(specifiedType);
    final parameterT =
        isUnderspecified ? FullType.object : specifiedType.parameters[0];

    final result = <Object>[];
    if (object.id != null) {
      result
        ..add('id')
        ..add(serializers.serialize(object.id,
            specifiedType: const FullType(int)));
    }
    if (object.title != null) {
      result
        ..add('title')
        ..add(serializers.serialize(object.title,
            specifiedType: const FullType(String)));
    }
    if (object.category != null) {
      result
        ..add('category')
        ..add(
            serializers.serialize(object.category, specifiedType: parameterT));
    }
    return result;
  }

  @override
  NewsItem deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final isUnderspecified =
        specifiedType.isUnspecified || specifiedType.parameters.isEmpty;
    if (!isUnderspecified) serializers.expectBuilder(specifiedType);
    final parameterT =
        isUnderspecified ? FullType.object : specifiedType.parameters[0];

    final result = isUnderspecified
        ? new NewsItemBuilder<Object>()
        : serializers.newBuilder(specifiedType) as NewsItemBuilder;

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'id':
          result.id = serializers.deserialize(value,
              specifiedType: const FullType(int)) as int;
          break;
        case 'title':
          result.title = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
        case 'category':
          result.category =
              serializers.deserialize(value, specifiedType: parameterT);
          break;
      }
    }

    return result.build();
  }
}

class _$GenericSerializer implements StructuredSerializer<Generic> {
  @override
  final Iterable<Type> types = const [Generic, _$Generic];
  @override
  final String wireName = 'Generic';

  @override
  Iterable<Object> serialize(Serializers serializers, Generic object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[];
    if (object.value != null) {
      result
        ..add('value')
        ..add(serializers.serialize(object.value,
            specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  Generic deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new GenericBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'value':
          result.value = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
      }
    }

    return result.build();
  }
}

class _$MediaTypeSerializer implements PrimitiveSerializer<MediaType> {
  @override
  final Iterable<Type> types = const <Type>[MediaType];
  @override
  final String wireName = 'MediaType';

  @override
  Object serialize(Serializers serializers, MediaType object,
          {FullType specifiedType = FullType.unspecified}) =>
      object.name;

  @override
  MediaType deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      MediaType.valueOf(serialized as String);
}

class _$NewsItem<T> extends NewsItem<T> {
  @override
  final int id;
  @override
  final String title;
  @override
  final T category;

  factory _$NewsItem([void Function(NewsItemBuilder<T>) updates]) =>
      (new NewsItemBuilder<T>()..update(updates)).build();

  _$NewsItem._({this.id, this.title, this.category}) : super._() {
    if (T == dynamic) {
      throw new BuiltValueMissingGenericsError('NewsItem', 'T');
    }
  }

  @override
  NewsItem<T> rebuild(void Function(NewsItemBuilder<T>) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NewsItemBuilder<T> toBuilder() => new NewsItemBuilder<T>()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NewsItem &&
        id == other.id &&
        title == other.title &&
        category == other.category;
  }

  @override
  int get hashCode {
    return $jf(
        $jc($jc($jc(0, id.hashCode), title.hashCode), category.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('NewsItem')
          ..add('id', id)
          ..add('title', title)
          ..add('category', category))
        .toString();
  }
}

class NewsItemBuilder<T> implements Builder<NewsItem<T>, NewsItemBuilder<T>> {
  _$NewsItem<T> _$v;

  int _id;
  int get id => _$this._id;
  set id(int id) => _$this._id = id;

  String _title;
  String get title => _$this._title;
  set title(String title) => _$this._title = title;

  T _category;
  T get category => _$this._category;
  set category(T category) => _$this._category = category;

  NewsItemBuilder();

  NewsItemBuilder<T> get _$this {
    if (_$v != null) {
      _id = _$v.id;
      _title = _$v.title;
      _category = _$v.category;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NewsItem<T> other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$NewsItem<T>;
  }

  @override
  void update(void Function(NewsItemBuilder<T>) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$NewsItem<T> build() {
    final _$result =
        _$v ?? new _$NewsItem<T>._(id: id, title: title, category: category);
    replace(_$result);
    return _$result;
  }
}

class _$Generic extends Generic {
  @override
  final String value;

  factory _$Generic([void Function(GenericBuilder) updates]) =>
      (new GenericBuilder()..update(updates)).build();

  _$Generic._({this.value}) : super._();

  @override
  Generic rebuild(void Function(GenericBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenericBuilder toBuilder() => new GenericBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Generic && value == other.value;
  }

  @override
  int get hashCode {
    return $jf($jc(0, value.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('Generic')..add('value', value))
        .toString();
  }
}

class GenericBuilder implements Builder<Generic, GenericBuilder> {
  _$Generic _$v;

  String _value;
  String get value => _$this._value;
  set value(String value) => _$this._value = value;

  GenericBuilder();

  GenericBuilder get _$this {
    if (_$v != null) {
      _value = _$v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Generic other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$Generic;
  }

  @override
  void update(void Function(GenericBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$Generic build() {
    final _$result = _$v ?? new _$Generic._(value: value);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new
