// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monitor_responses.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrameAnalysis {

 HiveStatus get status; DateTime get processedAt; int get riskScore; int get hornetCount; int get maxHornetCount; double get confidence; double get audioProbability; String? get snapshotUrl; String? get alertId;
/// Create a copy of FrameAnalysis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrameAnalysisCopyWith<FrameAnalysis> get copyWith => _$FrameAnalysisCopyWithImpl<FrameAnalysis>(this as FrameAnalysis, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FrameAnalysis;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrameAnalysis&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.processedAt, _this.processedAt) || other.processedAt == _this.processedAt)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore)&&(identical(other.hornetCount, _this.hornetCount) || other.hornetCount == _this.hornetCount)&&(identical(other.maxHornetCount, _this.maxHornetCount) || other.maxHornetCount == _this.maxHornetCount)&&(identical(other.confidence, _this.confidence) || other.confidence == _this.confidence)&&(identical(other.audioProbability, _this.audioProbability) || other.audioProbability == _this.audioProbability)&&(identical(other.snapshotUrl, _this.snapshotUrl) || other.snapshotUrl == _this.snapshotUrl)&&(identical(other.alertId, _this.alertId) || other.alertId == _this.alertId));
}


@override
int get hashCode {
  final _this = this as FrameAnalysis;
  return Object.hash(runtimeType,_this.status,_this.processedAt,_this.riskScore,_this.hornetCount,_this.maxHornetCount,_this.confidence,_this.audioProbability,_this.snapshotUrl,_this.alertId);
}

@override
String toString() {
  final _this = this as FrameAnalysis;
  return 'FrameAnalysis(status: ${_this.status}, processedAt: ${_this.processedAt}, riskScore: ${_this.riskScore}, hornetCount: ${_this.hornetCount}, maxHornetCount: ${_this.maxHornetCount}, confidence: ${_this.confidence}, audioProbability: ${_this.audioProbability}, snapshotUrl: ${_this.snapshotUrl}, alertId: ${_this.alertId})';
}


}

/// @nodoc
abstract mixin class $FrameAnalysisCopyWith<$Res>  {
  factory $FrameAnalysisCopyWith(FrameAnalysis value, $Res Function(FrameAnalysis) _then) = _$FrameAnalysisCopyWithImpl;
@useResult
$Res call({
 HiveStatus status, DateTime processedAt, int riskScore, int hornetCount, int maxHornetCount, double confidence, double audioProbability, String? snapshotUrl, String? alertId
});




}
/// @nodoc
class _$FrameAnalysisCopyWithImpl<$Res>
    implements $FrameAnalysisCopyWith<$Res> {
  _$FrameAnalysisCopyWithImpl(this._self, this._then);

  final FrameAnalysis _self;
  final $Res Function(FrameAnalysis) _then;

/// Create a copy of FrameAnalysis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? processedAt = null,Object? riskScore = null,Object? hornetCount = null,Object? maxHornetCount = null,Object? confidence = null,Object? audioProbability = null,Object? snapshotUrl = freezed,Object? alertId = freezed,}) {
  return _then(FrameAnalysis(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,snapshotUrl: freezed == snapshotUrl ? _self.snapshotUrl : snapshotUrl // ignore: cast_nullable_to_non_nullable
as String?,alertId: freezed == alertId ? _self.alertId : alertId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FrameAnalysis].
extension FrameAnalysisPatterns on FrameAnalysis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrameAnalysis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrameAnalysis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrameAnalysis value)  $default,){
final _that = this;
switch (_that) {
case _FrameAnalysis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrameAnalysis value)?  $default,){
final _that = this;
switch (_that) {
case _FrameAnalysis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HiveStatus status,  DateTime processedAt,  int riskScore,  int hornetCount,  int maxHornetCount,  double confidence,  double audioProbability,  String? snapshotUrl,  String? alertId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrameAnalysis() when $default != null:
return $default(_that.status,_that.processedAt,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.confidence,_that.audioProbability,_that.snapshotUrl,_that.alertId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HiveStatus status,  DateTime processedAt,  int riskScore,  int hornetCount,  int maxHornetCount,  double confidence,  double audioProbability,  String? snapshotUrl,  String? alertId)  $default,) {final _that = this;
switch (_that) {
case _FrameAnalysis():
return $default(_that.status,_that.processedAt,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.confidence,_that.audioProbability,_that.snapshotUrl,_that.alertId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HiveStatus status,  DateTime processedAt,  int riskScore,  int hornetCount,  int maxHornetCount,  double confidence,  double audioProbability,  String? snapshotUrl,  String? alertId)?  $default,) {final _that = this;
switch (_that) {
case _FrameAnalysis() when $default != null:
return $default(_that.status,_that.processedAt,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.confidence,_that.audioProbability,_that.snapshotUrl,_that.alertId);case _:
  return null;

}
}

}

/// @nodoc


class _FrameAnalysis extends FrameAnalysis {
  const _FrameAnalysis({required this.status, required this.processedAt, this.riskScore = 0, this.hornetCount = 0, this.maxHornetCount = 0, this.confidence = 0.0, this.audioProbability = 0.0, this.snapshotUrl, this.alertId}): super._();
  

@override final  HiveStatus status;
@override final  DateTime processedAt;
@override@JsonKey() final  int riskScore;
@override@JsonKey() final  int hornetCount;
@override@JsonKey() final  int maxHornetCount;
@override@JsonKey() final  double confidence;
@override@JsonKey() final  double audioProbability;
@override final  String? snapshotUrl;
@override final  String? alertId;

/// Create a copy of FrameAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrameAnalysisCopyWith<_FrameAnalysis> get copyWith => __$FrameAnalysisCopyWithImpl<_FrameAnalysis>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrameAnalysis&&(identical(other.status, status) || other.status == status)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore)&&(identical(other.hornetCount, hornetCount) || other.hornetCount == hornetCount)&&(identical(other.maxHornetCount, maxHornetCount) || other.maxHornetCount == maxHornetCount)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.audioProbability, audioProbability) || other.audioProbability == audioProbability)&&(identical(other.snapshotUrl, snapshotUrl) || other.snapshotUrl == snapshotUrl)&&(identical(other.alertId, alertId) || other.alertId == alertId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,processedAt,riskScore,hornetCount,maxHornetCount,confidence,audioProbability,snapshotUrl,alertId);
}

@override
String toString() {
    return 'FrameAnalysis(status: $status, processedAt: $processedAt, riskScore: $riskScore, hornetCount: $hornetCount, maxHornetCount: $maxHornetCount, confidence: $confidence, audioProbability: $audioProbability, snapshotUrl: $snapshotUrl, alertId: $alertId)';
}


}

/// @nodoc
abstract mixin class _$FrameAnalysisCopyWith<$Res> implements $FrameAnalysisCopyWith<$Res> {
  factory _$FrameAnalysisCopyWith(_FrameAnalysis value, $Res Function(_FrameAnalysis) _then) = __$FrameAnalysisCopyWithImpl;
@override @useResult
$Res call({
 HiveStatus status, DateTime processedAt, int riskScore, int hornetCount, int maxHornetCount, double confidence, double audioProbability, String? snapshotUrl, String? alertId
});




}
/// @nodoc
class __$FrameAnalysisCopyWithImpl<$Res>
    implements _$FrameAnalysisCopyWith<$Res> {
  __$FrameAnalysisCopyWithImpl(this._self, this._then);

  final _FrameAnalysis _self;
  final $Res Function(_FrameAnalysis) _then;

/// Create a copy of FrameAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? processedAt = null,Object? riskScore = null,Object? hornetCount = null,Object? maxHornetCount = null,Object? confidence = null,Object? audioProbability = null,Object? snapshotUrl = freezed,Object? alertId = freezed,}) {
  return _then(_FrameAnalysis(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,snapshotUrl: freezed == snapshotUrl ? _self.snapshotUrl : snapshotUrl // ignore: cast_nullable_to_non_nullable
as String?,alertId: freezed == alertId ? _self.alertId : alertId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AudioAnalysis {

 double get hornetProbability; DateTime get processedAt; HiveStatus? get status; int? get riskScore;
/// Create a copy of AudioAnalysis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioAnalysisCopyWith<AudioAnalysis> get copyWith => _$AudioAnalysisCopyWithImpl<AudioAnalysis>(this as AudioAnalysis, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AudioAnalysis;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioAnalysis&&(identical(other.hornetProbability, _this.hornetProbability) || other.hornetProbability == _this.hornetProbability)&&(identical(other.processedAt, _this.processedAt) || other.processedAt == _this.processedAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore));
}


@override
int get hashCode {
  final _this = this as AudioAnalysis;
  return Object.hash(runtimeType,_this.hornetProbability,_this.processedAt,_this.status,_this.riskScore);
}

@override
String toString() {
  final _this = this as AudioAnalysis;
  return 'AudioAnalysis(hornetProbability: ${_this.hornetProbability}, processedAt: ${_this.processedAt}, status: ${_this.status}, riskScore: ${_this.riskScore})';
}


}

/// @nodoc
abstract mixin class $AudioAnalysisCopyWith<$Res>  {
  factory $AudioAnalysisCopyWith(AudioAnalysis value, $Res Function(AudioAnalysis) _then) = _$AudioAnalysisCopyWithImpl;
@useResult
$Res call({
 double hornetProbability, DateTime processedAt, HiveStatus? status, int? riskScore
});




}
/// @nodoc
class _$AudioAnalysisCopyWithImpl<$Res>
    implements $AudioAnalysisCopyWith<$Res> {
  _$AudioAnalysisCopyWithImpl(this._self, this._then);

  final AudioAnalysis _self;
  final $Res Function(AudioAnalysis) _then;

/// Create a copy of AudioAnalysis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hornetProbability = null,Object? processedAt = null,Object? status = freezed,Object? riskScore = freezed,}) {
  return _then(AudioAnalysis(
hornetProbability: null == hornetProbability ? _self.hornetProbability : hornetProbability // ignore: cast_nullable_to_non_nullable
as double,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus?,riskScore: freezed == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioAnalysis].
extension AudioAnalysisPatterns on AudioAnalysis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioAnalysis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioAnalysis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioAnalysis value)  $default,){
final _that = this;
switch (_that) {
case _AudioAnalysis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioAnalysis value)?  $default,){
final _that = this;
switch (_that) {
case _AudioAnalysis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double hornetProbability,  DateTime processedAt,  HiveStatus? status,  int? riskScore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioAnalysis() when $default != null:
return $default(_that.hornetProbability,_that.processedAt,_that.status,_that.riskScore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double hornetProbability,  DateTime processedAt,  HiveStatus? status,  int? riskScore)  $default,) {final _that = this;
switch (_that) {
case _AudioAnalysis():
return $default(_that.hornetProbability,_that.processedAt,_that.status,_that.riskScore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double hornetProbability,  DateTime processedAt,  HiveStatus? status,  int? riskScore)?  $default,) {final _that = this;
switch (_that) {
case _AudioAnalysis() when $default != null:
return $default(_that.hornetProbability,_that.processedAt,_that.status,_that.riskScore);case _:
  return null;

}
}

}

/// @nodoc


class _AudioAnalysis extends AudioAnalysis {
  const _AudioAnalysis({required this.hornetProbability, required this.processedAt, this.status, this.riskScore}): super._();
  

@override final  double hornetProbability;
@override final  DateTime processedAt;
@override final  HiveStatus? status;
@override final  int? riskScore;

/// Create a copy of AudioAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioAnalysisCopyWith<_AudioAnalysis> get copyWith => __$AudioAnalysisCopyWithImpl<_AudioAnalysis>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioAnalysis&&(identical(other.hornetProbability, hornetProbability) || other.hornetProbability == hornetProbability)&&(identical(other.processedAt, processedAt) || other.processedAt == processedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hornetProbability,processedAt,status,riskScore);
}

@override
String toString() {
    return 'AudioAnalysis(hornetProbability: $hornetProbability, processedAt: $processedAt, status: $status, riskScore: $riskScore)';
}


}

/// @nodoc
abstract mixin class _$AudioAnalysisCopyWith<$Res> implements $AudioAnalysisCopyWith<$Res> {
  factory _$AudioAnalysisCopyWith(_AudioAnalysis value, $Res Function(_AudioAnalysis) _then) = __$AudioAnalysisCopyWithImpl;
@override @useResult
$Res call({
 double hornetProbability, DateTime processedAt, HiveStatus? status, int? riskScore
});




}
/// @nodoc
class __$AudioAnalysisCopyWithImpl<$Res>
    implements _$AudioAnalysisCopyWith<$Res> {
  __$AudioAnalysisCopyWithImpl(this._self, this._then);

  final _AudioAnalysis _self;
  final $Res Function(_AudioAnalysis) _then;

/// Create a copy of AudioAnalysis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hornetProbability = null,Object? processedAt = null,Object? status = freezed,Object? riskScore = freezed,}) {
  return _then(_AudioAnalysis(
hornetProbability: null == hornetProbability ? _self.hornetProbability : hornetProbability // ignore: cast_nullable_to_non_nullable
as double,processedAt: null == processedAt ? _self.processedAt : processedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus?,riskScore: freezed == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$HeartbeatAck {

 String get hiveId; HiveStatus get status; int get riskScore; bool get acknowledged;
/// Create a copy of HeartbeatAck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeartbeatAckCopyWith<HeartbeatAck> get copyWith => _$HeartbeatAckCopyWithImpl<HeartbeatAck>(this as HeartbeatAck, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HeartbeatAck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeartbeatAck&&(identical(other.hiveId, _this.hiveId) || other.hiveId == _this.hiveId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore)&&(identical(other.acknowledged, _this.acknowledged) || other.acknowledged == _this.acknowledged));
}


@override
int get hashCode {
  final _this = this as HeartbeatAck;
  return Object.hash(runtimeType,_this.hiveId,_this.status,_this.riskScore,_this.acknowledged);
}

@override
String toString() {
  final _this = this as HeartbeatAck;
  return 'HeartbeatAck(hiveId: ${_this.hiveId}, status: ${_this.status}, riskScore: ${_this.riskScore}, acknowledged: ${_this.acknowledged})';
}


}

/// @nodoc
abstract mixin class $HeartbeatAckCopyWith<$Res>  {
  factory $HeartbeatAckCopyWith(HeartbeatAck value, $Res Function(HeartbeatAck) _then) = _$HeartbeatAckCopyWithImpl;
@useResult
$Res call({
 String hiveId, HiveStatus status, int riskScore, bool acknowledged
});




}
/// @nodoc
class _$HeartbeatAckCopyWithImpl<$Res>
    implements $HeartbeatAckCopyWith<$Res> {
  _$HeartbeatAckCopyWithImpl(this._self, this._then);

  final HeartbeatAck _self;
  final $Res Function(HeartbeatAck) _then;

/// Create a copy of HeartbeatAck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hiveId = null,Object? status = null,Object? riskScore = null,Object? acknowledged = null,}) {
  return _then(HeartbeatAck(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,acknowledged: null == acknowledged ? _self.acknowledged : acknowledged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HeartbeatAck].
extension HeartbeatAckPatterns on HeartbeatAck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeartbeatAck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeartbeatAck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeartbeatAck value)  $default,){
final _that = this;
switch (_that) {
case _HeartbeatAck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeartbeatAck value)?  $default,){
final _that = this;
switch (_that) {
case _HeartbeatAck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hiveId,  HiveStatus status,  int riskScore,  bool acknowledged)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeartbeatAck() when $default != null:
return $default(_that.hiveId,_that.status,_that.riskScore,_that.acknowledged);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hiveId,  HiveStatus status,  int riskScore,  bool acknowledged)  $default,) {final _that = this;
switch (_that) {
case _HeartbeatAck():
return $default(_that.hiveId,_that.status,_that.riskScore,_that.acknowledged);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hiveId,  HiveStatus status,  int riskScore,  bool acknowledged)?  $default,) {final _that = this;
switch (_that) {
case _HeartbeatAck() when $default != null:
return $default(_that.hiveId,_that.status,_that.riskScore,_that.acknowledged);case _:
  return null;

}
}

}

/// @nodoc


class _HeartbeatAck extends HeartbeatAck {
  const _HeartbeatAck({required this.hiveId, required this.status, this.riskScore = 0, this.acknowledged = true}): super._();
  

@override final  String hiveId;
@override final  HiveStatus status;
@override@JsonKey() final  int riskScore;
@override@JsonKey() final  bool acknowledged;

/// Create a copy of HeartbeatAck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeartbeatAckCopyWith<_HeartbeatAck> get copyWith => __$HeartbeatAckCopyWithImpl<_HeartbeatAck>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeartbeatAck&&(identical(other.hiveId, hiveId) || other.hiveId == hiveId)&&(identical(other.status, status) || other.status == status)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore)&&(identical(other.acknowledged, acknowledged) || other.acknowledged == acknowledged));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hiveId,status,riskScore,acknowledged);
}

@override
String toString() {
    return 'HeartbeatAck(hiveId: $hiveId, status: $status, riskScore: $riskScore, acknowledged: $acknowledged)';
}


}

/// @nodoc
abstract mixin class _$HeartbeatAckCopyWith<$Res> implements $HeartbeatAckCopyWith<$Res> {
  factory _$HeartbeatAckCopyWith(_HeartbeatAck value, $Res Function(_HeartbeatAck) _then) = __$HeartbeatAckCopyWithImpl;
@override @useResult
$Res call({
 String hiveId, HiveStatus status, int riskScore, bool acknowledged
});




}
/// @nodoc
class __$HeartbeatAckCopyWithImpl<$Res>
    implements _$HeartbeatAckCopyWith<$Res> {
  __$HeartbeatAckCopyWithImpl(this._self, this._then);

  final _HeartbeatAck _self;
  final $Res Function(_HeartbeatAck) _then;

/// Create a copy of HeartbeatAck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hiveId = null,Object? status = null,Object? riskScore = null,Object? acknowledged = null,}) {
  return _then(_HeartbeatAck(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,acknowledged: null == acknowledged ? _self.acknowledged : acknowledged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
