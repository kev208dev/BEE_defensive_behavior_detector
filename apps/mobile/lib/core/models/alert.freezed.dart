// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'alert.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AlertSummary {

 String get id; String get hiveId; String get hiveName; DateTime get timestamp; AlertSeverity get severity; int get riskScore; int get hornetCount; String get message;
/// Create a copy of AlertSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertSummaryCopyWith<AlertSummary> get copyWith => _$AlertSummaryCopyWithImpl<AlertSummary>(this as AlertSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AlertSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.hiveId, _this.hiveId) || other.hiveId == _this.hiveId)&&(identical(other.hiveName, _this.hiveName) || other.hiveName == _this.hiveName)&&(identical(other.timestamp, _this.timestamp) || other.timestamp == _this.timestamp)&&(identical(other.severity, _this.severity) || other.severity == _this.severity)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore)&&(identical(other.hornetCount, _this.hornetCount) || other.hornetCount == _this.hornetCount)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as AlertSummary;
  return Object.hash(runtimeType,_this.id,_this.hiveId,_this.hiveName,_this.timestamp,_this.severity,_this.riskScore,_this.hornetCount,_this.message);
}

@override
String toString() {
  final _this = this as AlertSummary;
  return 'AlertSummary(id: ${_this.id}, hiveId: ${_this.hiveId}, hiveName: ${_this.hiveName}, timestamp: ${_this.timestamp}, severity: ${_this.severity}, riskScore: ${_this.riskScore}, hornetCount: ${_this.hornetCount}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $AlertSummaryCopyWith<$Res>  {
  factory $AlertSummaryCopyWith(AlertSummary value, $Res Function(AlertSummary) _then) = _$AlertSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String hiveId, String hiveName, DateTime timestamp, AlertSeverity severity, int riskScore, int hornetCount, String message
});




}
/// @nodoc
class _$AlertSummaryCopyWithImpl<$Res>
    implements $AlertSummaryCopyWith<$Res> {
  _$AlertSummaryCopyWithImpl(this._self, this._then);

  final AlertSummary _self;
  final $Res Function(AlertSummary) _then;

/// Create a copy of AlertSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hiveId = null,Object? hiveName = null,Object? timestamp = null,Object? severity = null,Object? riskScore = null,Object? hornetCount = null,Object? message = null,}) {
  return _then(AlertSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as AlertSeverity,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AlertSummary].
extension AlertSummaryPatterns on AlertSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertSummary value)  $default,){
final _that = this;
switch (_that) {
case _AlertSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AlertSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String hiveId,  String hiveName,  DateTime timestamp,  AlertSeverity severity,  int riskScore,  int hornetCount,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertSummary() when $default != null:
return $default(_that.id,_that.hiveId,_that.hiveName,_that.timestamp,_that.severity,_that.riskScore,_that.hornetCount,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String hiveId,  String hiveName,  DateTime timestamp,  AlertSeverity severity,  int riskScore,  int hornetCount,  String message)  $default,) {final _that = this;
switch (_that) {
case _AlertSummary():
return $default(_that.id,_that.hiveId,_that.hiveName,_that.timestamp,_that.severity,_that.riskScore,_that.hornetCount,_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String hiveId,  String hiveName,  DateTime timestamp,  AlertSeverity severity,  int riskScore,  int hornetCount,  String message)?  $default,) {final _that = this;
switch (_that) {
case _AlertSummary() when $default != null:
return $default(_that.id,_that.hiveId,_that.hiveName,_that.timestamp,_that.severity,_that.riskScore,_that.hornetCount,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _AlertSummary extends AlertSummary {
  const _AlertSummary({required this.id, required this.hiveId, required this.hiveName, required this.timestamp, required this.severity, this.riskScore = 0, this.hornetCount = 0, this.message = ''}): super._();
  

@override final  String id;
@override final  String hiveId;
@override final  String hiveName;
@override final  DateTime timestamp;
@override final  AlertSeverity severity;
@override@JsonKey() final  int riskScore;
@override@JsonKey() final  int hornetCount;
@override@JsonKey() final  String message;

/// Create a copy of AlertSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertSummaryCopyWith<_AlertSummary> get copyWith => __$AlertSummaryCopyWithImpl<_AlertSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.hiveId, hiveId) || other.hiveId == hiveId)&&(identical(other.hiveName, hiveName) || other.hiveName == hiveName)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore)&&(identical(other.hornetCount, hornetCount) || other.hornetCount == hornetCount)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,hiveId,hiveName,timestamp,severity,riskScore,hornetCount,message);
}

@override
String toString() {
    return 'AlertSummary(id: $id, hiveId: $hiveId, hiveName: $hiveName, timestamp: $timestamp, severity: $severity, riskScore: $riskScore, hornetCount: $hornetCount, message: $message)';
}


}

/// @nodoc
abstract mixin class _$AlertSummaryCopyWith<$Res> implements $AlertSummaryCopyWith<$Res> {
  factory _$AlertSummaryCopyWith(_AlertSummary value, $Res Function(_AlertSummary) _then) = __$AlertSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String hiveId, String hiveName, DateTime timestamp, AlertSeverity severity, int riskScore, int hornetCount, String message
});




}
/// @nodoc
class __$AlertSummaryCopyWithImpl<$Res>
    implements _$AlertSummaryCopyWith<$Res> {
  __$AlertSummaryCopyWithImpl(this._self, this._then);

  final _AlertSummary _self;
  final $Res Function(_AlertSummary) _then;

/// Create a copy of AlertSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hiveId = null,Object? hiveName = null,Object? timestamp = null,Object? severity = null,Object? riskScore = null,Object? hornetCount = null,Object? message = null,}) {
  return _then(_AlertSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as AlertSeverity,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AlertDetail {

 AlertSummary get summary; int get maxHornetCount; double get audioProbability; double get persistenceRatio; double get growthPerSecond; String get explanation; String? get thumbnailUrl; String? get clipUrl; DateTime? get resolvedAt;
/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertDetailCopyWith<AlertDetail> get copyWith => _$AlertDetailCopyWithImpl<AlertDetail>(this as AlertDetail, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AlertDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertDetail&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.maxHornetCount, _this.maxHornetCount) || other.maxHornetCount == _this.maxHornetCount)&&(identical(other.audioProbability, _this.audioProbability) || other.audioProbability == _this.audioProbability)&&(identical(other.persistenceRatio, _this.persistenceRatio) || other.persistenceRatio == _this.persistenceRatio)&&(identical(other.growthPerSecond, _this.growthPerSecond) || other.growthPerSecond == _this.growthPerSecond)&&(identical(other.explanation, _this.explanation) || other.explanation == _this.explanation)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.clipUrl, _this.clipUrl) || other.clipUrl == _this.clipUrl)&&(identical(other.resolvedAt, _this.resolvedAt) || other.resolvedAt == _this.resolvedAt));
}


@override
int get hashCode {
  final _this = this as AlertDetail;
  return Object.hash(runtimeType,_this.summary,_this.maxHornetCount,_this.audioProbability,_this.persistenceRatio,_this.growthPerSecond,_this.explanation,_this.thumbnailUrl,_this.clipUrl,_this.resolvedAt);
}

@override
String toString() {
  final _this = this as AlertDetail;
  return 'AlertDetail(summary: ${_this.summary}, maxHornetCount: ${_this.maxHornetCount}, audioProbability: ${_this.audioProbability}, persistenceRatio: ${_this.persistenceRatio}, growthPerSecond: ${_this.growthPerSecond}, explanation: ${_this.explanation}, thumbnailUrl: ${_this.thumbnailUrl}, clipUrl: ${_this.clipUrl}, resolvedAt: ${_this.resolvedAt})';
}


}

/// @nodoc
abstract mixin class $AlertDetailCopyWith<$Res>  {
  factory $AlertDetailCopyWith(AlertDetail value, $Res Function(AlertDetail) _then) = _$AlertDetailCopyWithImpl;
@useResult
$Res call({
 AlertSummary summary, int maxHornetCount, double audioProbability, double persistenceRatio, double growthPerSecond, String explanation, String? thumbnailUrl, String? clipUrl, DateTime? resolvedAt
});


$AlertSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class _$AlertDetailCopyWithImpl<$Res>
    implements $AlertDetailCopyWith<$Res> {
  _$AlertDetailCopyWithImpl(this._self, this._then);

  final AlertDetail _self;
  final $Res Function(AlertDetail) _then;

/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? persistenceRatio = null,Object? growthPerSecond = null,Object? explanation = null,Object? thumbnailUrl = freezed,Object? clipUrl = freezed,Object? resolvedAt = freezed,}) {
  return _then(AlertDetail(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as AlertSummary,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,persistenceRatio: null == persistenceRatio ? _self.persistenceRatio : persistenceRatio // ignore: cast_nullable_to_non_nullable
as double,growthPerSecond: null == growthPerSecond ? _self.growthPerSecond : growthPerSecond // ignore: cast_nullable_to_non_nullable
as double,explanation: null == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,clipUrl: freezed == clipUrl ? _self.clipUrl : clipUrl // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AlertSummaryCopyWith<$Res> get summary {
  
  return $AlertSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [AlertDetail].
extension AlertDetailPatterns on AlertDetail {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertDetail() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertDetail value)  $default,){
final _that = this;
switch (_that) {
case _AlertDetail():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertDetail value)?  $default,){
final _that = this;
switch (_that) {
case _AlertDetail() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AlertSummary summary,  int maxHornetCount,  double audioProbability,  double persistenceRatio,  double growthPerSecond,  String explanation,  String? thumbnailUrl,  String? clipUrl,  DateTime? resolvedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertDetail() when $default != null:
return $default(_that.summary,_that.maxHornetCount,_that.audioProbability,_that.persistenceRatio,_that.growthPerSecond,_that.explanation,_that.thumbnailUrl,_that.clipUrl,_that.resolvedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AlertSummary summary,  int maxHornetCount,  double audioProbability,  double persistenceRatio,  double growthPerSecond,  String explanation,  String? thumbnailUrl,  String? clipUrl,  DateTime? resolvedAt)  $default,) {final _that = this;
switch (_that) {
case _AlertDetail():
return $default(_that.summary,_that.maxHornetCount,_that.audioProbability,_that.persistenceRatio,_that.growthPerSecond,_that.explanation,_that.thumbnailUrl,_that.clipUrl,_that.resolvedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AlertSummary summary,  int maxHornetCount,  double audioProbability,  double persistenceRatio,  double growthPerSecond,  String explanation,  String? thumbnailUrl,  String? clipUrl,  DateTime? resolvedAt)?  $default,) {final _that = this;
switch (_that) {
case _AlertDetail() when $default != null:
return $default(_that.summary,_that.maxHornetCount,_that.audioProbability,_that.persistenceRatio,_that.growthPerSecond,_that.explanation,_that.thumbnailUrl,_that.clipUrl,_that.resolvedAt);case _:
  return null;

}
}

}

/// @nodoc


class _AlertDetail extends AlertDetail {
  const _AlertDetail({required this.summary, this.maxHornetCount = 0, this.audioProbability = 0.0, this.persistenceRatio = 0.0, this.growthPerSecond = 0.0, this.explanation = '', this.thumbnailUrl, this.clipUrl, this.resolvedAt}): super._();
  

@override final  AlertSummary summary;
@override@JsonKey() final  int maxHornetCount;
@override@JsonKey() final  double audioProbability;
@override@JsonKey() final  double persistenceRatio;
@override@JsonKey() final  double growthPerSecond;
@override@JsonKey() final  String explanation;
@override final  String? thumbnailUrl;
@override final  String? clipUrl;
@override final  DateTime? resolvedAt;

/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertDetailCopyWith<_AlertDetail> get copyWith => __$AlertDetailCopyWithImpl<_AlertDetail>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertDetail&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.maxHornetCount, maxHornetCount) || other.maxHornetCount == maxHornetCount)&&(identical(other.audioProbability, audioProbability) || other.audioProbability == audioProbability)&&(identical(other.persistenceRatio, persistenceRatio) || other.persistenceRatio == persistenceRatio)&&(identical(other.growthPerSecond, growthPerSecond) || other.growthPerSecond == growthPerSecond)&&(identical(other.explanation, explanation) || other.explanation == explanation)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.clipUrl, clipUrl) || other.clipUrl == clipUrl)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,summary,maxHornetCount,audioProbability,persistenceRatio,growthPerSecond,explanation,thumbnailUrl,clipUrl,resolvedAt);
}

@override
String toString() {
    return 'AlertDetail(summary: $summary, maxHornetCount: $maxHornetCount, audioProbability: $audioProbability, persistenceRatio: $persistenceRatio, growthPerSecond: $growthPerSecond, explanation: $explanation, thumbnailUrl: $thumbnailUrl, clipUrl: $clipUrl, resolvedAt: $resolvedAt)';
}


}

/// @nodoc
abstract mixin class _$AlertDetailCopyWith<$Res> implements $AlertDetailCopyWith<$Res> {
  factory _$AlertDetailCopyWith(_AlertDetail value, $Res Function(_AlertDetail) _then) = __$AlertDetailCopyWithImpl;
@override @useResult
$Res call({
 AlertSummary summary, int maxHornetCount, double audioProbability, double persistenceRatio, double growthPerSecond, String explanation, String? thumbnailUrl, String? clipUrl, DateTime? resolvedAt
});


@override $AlertSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class __$AlertDetailCopyWithImpl<$Res>
    implements _$AlertDetailCopyWith<$Res> {
  __$AlertDetailCopyWithImpl(this._self, this._then);

  final _AlertDetail _self;
  final $Res Function(_AlertDetail) _then;

/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? persistenceRatio = null,Object? growthPerSecond = null,Object? explanation = null,Object? thumbnailUrl = freezed,Object? clipUrl = freezed,Object? resolvedAt = freezed,}) {
  return _then(_AlertDetail(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as AlertSummary,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,persistenceRatio: null == persistenceRatio ? _self.persistenceRatio : persistenceRatio // ignore: cast_nullable_to_non_nullable
as double,growthPerSecond: null == growthPerSecond ? _self.growthPerSecond : growthPerSecond // ignore: cast_nullable_to_non_nullable
as double,explanation: null == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,clipUrl: freezed == clipUrl ? _self.clipUrl : clipUrl // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of AlertDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AlertSummaryCopyWith<$Res> get summary {
  
  return $AlertSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

// dart format on
