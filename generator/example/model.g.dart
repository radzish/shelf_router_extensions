// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<NewsItem> _$newsItemSerializer = new _$NewsItemSerializer();

class _$NewsItemSerializer implements StructuredSerializer<NewsItem> {
  @override
  final Iterable<Type> types = const [NewsItem, _$NewsItem];
  @override
  final String wireName = 'NewsItem';

  @override
  Iterable<Object> serialize(Serializers serializers, NewsItem object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[
      'id',
      serializers.serialize(object.id, specifiedType: const FullType(int)),
      'title',
      serializers.serialize(object.title,
          specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  NewsItem deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new NewsItemBuilder();

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
      }
    }

    return result.build();
  }
}

class _$NewsItem extends NewsItem {
  @override
  final int id;
  @override
  final String title;

  factory _$NewsItem([void Function(NewsItemBuilder) updates]) =>
      (new NewsItemBuilder()..update(updates)).build();

  _$NewsItem._({this.id, this.title}) : super._() {
    if (id == null) {
      throw new BuiltValueNullFieldError('NewsItem', 'id');
    }
    if (title == null) {
      throw new BuiltValueNullFieldError('NewsItem', 'title');
    }
  }

  @override
  NewsItem rebuild(void Function(NewsItemBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NewsItemBuilder toBuilder() => new NewsItemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NewsItem && id == other.id && title == other.title;
  }

  @override
  int get hashCode {
    return $jf($jc($jc(0, id.hashCode), title.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('NewsItem')
          ..add('id', id)
          ..add('title', title))
        .toString();
  }
}

class NewsItemBuilder implements Builder<NewsItem, NewsItemBuilder> {
  _$NewsItem _$v;

  int _id;
  int get id => _$this._id;
  set id(int id) => _$this._id = id;

  String _title;
  String get title => _$this._title;
  set title(String title) => _$this._title = title;

  NewsItemBuilder();

  NewsItemBuilder get _$this {
    if (_$v != null) {
      _id = _$v.id;
      _title = _$v.title;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NewsItem other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$NewsItem;
  }

  @override
  void update(void Function(NewsItemBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$NewsItem build() {
    final _$result = _$v ?? new _$NewsItem._(id: id, title: title);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new
