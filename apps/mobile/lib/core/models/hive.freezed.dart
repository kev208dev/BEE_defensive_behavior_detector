// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hive.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Hive {

 String get id; String get name; HiveStatus get status; int get riskScore; int get hornetCount; DateTime get lastUpdated; String get location; int get maxHornetCount; double get audioProbability; bool get monitoringOnline; DateTime? get lastHeartbeat;
/// Create a copy of Hive
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HiveCopyWith<Hive> get copyWith => _$HiveCopyWithImpl<Hive>(this as Hive, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Hive;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Hive&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore)&&(identical(other.hornetCount, _this.hornetCount) || other.hornetCount == _this.hornetCount)&&(identical(other.lastUpdated, _this.lastUpdated) || other.lastUpdated == _this.lastUpdated)&&(identical(other.location, _this.location) || other.location == _this.location)&&(identical(other.maxHornetCount, _this.maxHornetCount) || other.maxHornetCount == _this.maxHornetCount)&&(identical(other.audioProbability, _this.audioProbability) || other.audioProbability == _this.audioProbability)&&(identical(other.monitoringOnline, _this.monitoringOnline) || other.monitoringOnline == _this.monitoringOnline)&&(identical(other.lastHeartbeat, _this.lastHeartbeat) || other.lastHeartbeat == _this.lastHeartbeat));
}


@override
int get hashCode {
  final _this = this as Hive;
  return Object.hash(runtimeType,_this.id,_this.name,_this.status,_this.riskScore,_this.hornetCount,_this.lastUpdated,_this.location,_this.maxHornetCount,_this.audioProbability,_this.monitoringOnline,_this.lastHeartbeat);
}

@override
String toString() {
  final _this = this as Hive;
  return 'Hive(id: ${_this.id}, name: ${_this.name}, status: ${_this.status}, riskScore: ${_this.riskScore}, hornetCount: ${_this.hornetCount}, lastUpdated: ${_this.lastUpdated}, location: ${_this.location}, maxHornetCount: ${_this.maxHornetCount}, audioProbability: ${_this.audioProbability}, monitoringOnline: ${_this.monitoringOnline}, lastHeartbeat: ${_this.lastHeartbeat})';
}


}

/// @nodoc
abstract mixin class $HiveCopyWith<$Res>  {
  factory $HiveCopyWith(Hive value, $Res Function(Hive) _then) = _$HiveCopyWithImpl;
@useResult
$Res call({
 String id, String name, HiveStatus status, int riskScore, int hornetCount, DateTime lastUpdated, String location, int maxHornetCount, double audioProbability, bool monitoringOnline, DateTime? lastHeartbeat
});




}
/// @nodoc
class _$HiveCopyWithImpl<$Res>
    implements $HiveCopyWith<$Res> {
  _$HiveCopyWithImpl(this._self, this._then);

  final Hive _self;
  final $Res Function(Hive) _then;

/// Create a copy of Hive
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? status = null,Object? riskScore = null,Object? hornetCount = null,Object? lastUpdated = null,Object? location = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? monitoringOnline = null,Object? lastHeartbeat = freezed,}) {
  return _then(Hive(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,monitoringOnline: null == monitoringOnline ? _self.monitoringOnline : monitoringOnline // ignore: cast_nullable_to_non_nullable
as bool,lastHeartbeat: freezed == lastHeartbeat ? _self.lastHeartbeat : lastHeartbeat // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Hive].
extension HivePatterns on Hive {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Hive value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Hive() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Hive value)  $default,){
final _that = this;
switch (_that) {
case _Hive():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Hive value)?  $default,){
final _that = this;
switch (_that) {
case _Hive() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  HiveStatus status,  int riskScore,  int hornetCount,  DateTime lastUpdated,  String location,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  DateTime? lastHeartbeat)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Hive() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.riskScore,_that.hornetCount,_that.lastUpdated,_that.location,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.lastHeartbeat);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  HiveStatus status,  int riskScore,  int hornetCount,  DateTime lastUpdated,  String location,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  DateTime? lastHeartbeat)  $default,) {final _that = this;
switch (_that) {
case _Hive():
return $default(_that.id,_that.name,_that.status,_that.riskScore,_that.hornetCount,_that.lastUpdated,_that.location,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.lastHeartbeat);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  HiveStatus status,  int riskScore,  int hornetCount,  DateTime lastUpdated,  String location,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  DateTime? lastHeartbeat)?  $default,) {final _that = this;
switch (_that) {
case _Hive() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.riskScore,_that.hornetCount,_that.lastUpdated,_that.location,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.lastHeartbeat);case _:
  return null;

}
}

}

/// @nodoc


class _Hive extends Hive {
  const _Hive({required this.id, required this.name, required this.status, required this.riskScore, required this.hornetCount, required this.lastUpdated, this.location = '', this.maxHornetCount = 0, this.audioProbability = 0.0, this.monitoringOnline = false, this.lastHeartbeat}): super._();
  

@override final  String id;
@override final  String name;
@override final  HiveStatus status;
@override final  int riskScore;
@override final  int hornetCount;
@override final  DateTime lastUpdated;
@override@JsonKey() final  String location;
@override@JsonKey() final  int maxHornetCount;
@override@JsonKey() final  double audioProbability;
@override@JsonKey() final  bool monitoringOnline;
@override final  DateTime? lastHeartbeat;

/// Create a copy of Hive
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HiveCopyWith<_Hive> get copyWith => __$HiveCopyWithImpl<_Hive>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Hive&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore)&&(identical(other.hornetCount, hornetCount) || other.hornetCount == hornetCount)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.location, location) || other.location == location)&&(identical(other.maxHornetCount, maxHornetCount) || other.maxHornetCount == maxHornetCount)&&(identical(other.audioProbability, audioProbability) || other.audioProbability == audioProbability)&&(identical(other.monitoringOnline, monitoringOnline) || other.monitoringOnline == monitoringOnline)&&(identical(other.lastHeartbeat, lastHeartbeat) || other.lastHeartbeat == lastHeartbeat));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,status,riskScore,hornetCount,lastUpdated,location,maxHornetCount,audioProbability,monitoringOnline,lastHeartbeat);
}

@override
String toString() {
    return 'Hive(id: $id, name: $name, status: $status, riskScore: $riskScore, hornetCount: $hornetCount, lastUpdated: $lastUpdated, location: $location, maxHornetCount: $maxHornetCount, audioProbability: $audioProbability, monitoringOnline: $monitoringOnline, lastHeartbeat: $lastHeartbeat)';
}


}

/// @nodoc
abstract mixin class _$HiveCopyWith<$Res> implements $HiveCopyWith<$Res> {
  factory _$HiveCopyWith(_Hive value, $Res Function(_Hive) _then) = __$HiveCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, HiveStatus status, int riskScore, int hornetCount, DateTime lastUpdated, String location, int maxHornetCount, double audioProbability, bool monitoringOnline, DateTime? lastHeartbeat
});




}
/// @nodoc
class __$HiveCopyWithImpl<$Res>
    implements _$HiveCopyWith<$Res> {
  __$HiveCopyWithImpl(this._self, this._then);

  final _Hive _self;
  final $Res Function(_Hive) _then;

/// Create a copy of Hive
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? riskScore = null,Object? hornetCount = null,Object? lastUpdated = null,Object? location = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? monitoringOnline = null,Object? lastHeartbeat = freezed,}) {
  return _then(_Hive(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,lastUpdated: null == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,monitoringOnline: null == monitoringOnline ? _self.monitoringOnline : monitoringOnline // ignore: cast_nullable_to_non_nullable
as bool,lastHeartbeat: freezed == lastHeartbeat ? _self.lastHeartbeat : lastHeartbeat // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$HiveDetail {

 Hive get hive; double get persistenceRatio; double get growthPerSecond; bool get cameraOk; bool get microphoneOk; bool get monitoring; String get statusReason; String? get latestSnapshotUrl; DateTime? get lastAnalyzedAt; List<AlertSummary> get recentAlerts;
/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HiveDetailCopyWith<HiveDetail> get copyWith => _$HiveDetailCopyWithImpl<HiveDetail>(this as HiveDetail, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HiveDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HiveDetail&&(identical(other.hive, _this.hive) || other.hive == _this.hive)&&(identical(other.persistenceRatio, _this.persistenceRatio) || other.persistenceRatio == _this.persistenceRatio)&&(identical(other.growthPerSecond, _this.growthPerSecond) || other.growthPerSecond == _this.growthPerSecond)&&(identical(other.cameraOk, _this.cameraOk) || other.cameraOk == _this.cameraOk)&&(identical(other.microphoneOk, _this.microphoneOk) || other.microphoneOk == _this.microphoneOk)&&(identical(other.monitoring, _this.monitoring) || other.monitoring == _this.monitoring)&&(identical(other.statusReason, _this.statusReason) || other.statusReason == _this.statusReason)&&(identical(other.latestSnapshotUrl, _this.latestSnapshotUrl) || other.latestSnapshotUrl == _this.latestSnapshotUrl)&&(identical(other.lastAnalyzedAt, _this.lastAnalyzedAt) || other.lastAnalyzedAt == _this.lastAnalyzedAt)&&const DeepCollectionEquality().equals(other.recentAlerts, _this.recentAlerts));
}


@override
int get hashCode {
  final _this = this as HiveDetail;
  return Object.hash(runtimeType,_this.hive,_this.persistenceRatio,_this.growthPerSecond,_this.cameraOk,_this.microphoneOk,_this.monitoring,_this.statusReason,_this.latestSnapshotUrl,_this.lastAnalyzedAt,const DeepCollectionEquality().hash(_this.recentAlerts));
}

@override
String toString() {
  final _this = this as HiveDetail;
  return 'HiveDetail(hive: ${_this.hive}, persistenceRatio: ${_this.persistenceRatio}, growthPerSecond: ${_this.growthPerSecond}, cameraOk: ${_this.cameraOk}, microphoneOk: ${_this.microphoneOk}, monitoring: ${_this.monitoring}, statusReason: ${_this.statusReason}, latestSnapshotUrl: ${_this.latestSnapshotUrl}, lastAnalyzedAt: ${_this.lastAnalyzedAt}, recentAlerts: ${_this.recentAlerts})';
}


}

/// @nodoc
abstract mixin class $HiveDetailCopyWith<$Res>  {
  factory $HiveDetailCopyWith(HiveDetail value, $Res Function(HiveDetail) _then) = _$HiveDetailCopyWithImpl;
@useResult
$Res call({
 Hive hive, double persistenceRatio, double growthPerSecond, bool cameraOk, bool microphoneOk, bool monitoring, String statusReason, String? latestSnapshotUrl, DateTime? lastAnalyzedAt, List<AlertSummary> recentAlerts
});


$HiveCopyWith<$Res> get hive;

}
/// @nodoc
class _$HiveDetailCopyWithImpl<$Res>
    implements $HiveDetailCopyWith<$Res> {
  _$HiveDetailCopyWithImpl(this._self, this._then);

  final HiveDetail _self;
  final $Res Function(HiveDetail) _then;

/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hive = null,Object? persistenceRatio = null,Object? growthPerSecond = null,Object? cameraOk = null,Object? microphoneOk = null,Object? monitoring = null,Object? statusReason = null,Object? latestSnapshotUrl = freezed,Object? lastAnalyzedAt = freezed,Object? recentAlerts = null,}) {
  return _then(HiveDetail(
hive: null == hive ? _self.hive : hive // ignore: cast_nullable_to_non_nullable
as Hive,persistenceRatio: null == persistenceRatio ? _self.persistenceRatio : persistenceRatio // ignore: cast_nullable_to_non_nullable
as double,growthPerSecond: null == growthPerSecond ? _self.growthPerSecond : growthPerSecond // ignore: cast_nullable_to_non_nullable
as double,cameraOk: null == cameraOk ? _self.cameraOk : cameraOk // ignore: cast_nullable_to_non_nullable
as bool,microphoneOk: null == microphoneOk ? _self.microphoneOk : microphoneOk // ignore: cast_nullable_to_non_nullable
as bool,monitoring: null == monitoring ? _self.monitoring : monitoring // ignore: cast_nullable_to_non_nullable
as bool,statusReason: null == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String,latestSnapshotUrl: freezed == latestSnapshotUrl ? _self.latestSnapshotUrl : latestSnapshotUrl // ignore: cast_nullable_to_non_nullable
as String?,lastAnalyzedAt: freezed == lastAnalyzedAt ? _self.lastAnalyzedAt : lastAnalyzedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recentAlerts: null == recentAlerts ? _self.recentAlerts : recentAlerts // ignore: cast_nullable_to_non_nullable
as List<AlertSummary>,
  ));
}
/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HiveCopyWith<$Res> get hive {
  
  return $HiveCopyWith<$Res>(_self.hive, (value) {
    return _then(_self.copyWith(hive: value));
  });
}
}


/// Adds pattern-matching-related methods to [HiveDetail].
extension HiveDetailPatterns on HiveDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HiveDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HiveDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HiveDetail value)  $default,){
final _that = this;
switch (_that) {
case _HiveDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HiveDetail value)?  $default,){
final _that = this;
switch (_that) {
case _HiveDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Hive hive,  double persistenceRatio,  double growthPerSecond,  bool cameraOk,  bool microphoneOk,  bool monitoring,  String statusReason,  String? latestSnapshotUrl,  DateTime? lastAnalyzedAt,  List<AlertSummary> recentAlerts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HiveDetail() when $default != null:
return $default(_that.hive,_that.persistenceRatio,_that.growthPerSecond,_that.cameraOk,_that.microphoneOk,_that.monitoring,_that.statusReason,_that.latestSnapshotUrl,_that.lastAnalyzedAt,_that.recentAlerts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Hive hive,  double persistenceRatio,  double growthPerSecond,  bool cameraOk,  bool microphoneOk,  bool monitoring,  String statusReason,  String? latestSnapshotUrl,  DateTime? lastAnalyzedAt,  List<AlertSummary> recentAlerts)  $default,) {final _that = this;
switch (_that) {
case _HiveDetail():
return $default(_that.hive,_that.persistenceRatio,_that.growthPerSecond,_that.cameraOk,_that.microphoneOk,_that.monitoring,_that.statusReason,_that.latestSnapshotUrl,_that.lastAnalyzedAt,_that.recentAlerts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Hive hive,  double persistenceRatio,  double growthPerSecond,  bool cameraOk,  bool microphoneOk,  bool monitoring,  String statusReason,  String? latestSnapshotUrl,  DateTime? lastAnalyzedAt,  List<AlertSummary> recentAlerts)?  $default,) {final _that = this;
switch (_that) {
case _HiveDetail() when $default != null:
return $default(_that.hive,_that.persistenceRatio,_that.growthPerSecond,_that.cameraOk,_that.microphoneOk,_that.monitoring,_that.statusReason,_that.latestSnapshotUrl,_that.lastAnalyzedAt,_that.recentAlerts);case _:
  return null;

}
}

}

/// @nodoc


class _HiveDetail extends HiveDetail {
  const _HiveDetail({required this.hive, this.persistenceRatio = 0.0, this.growthPerSecond = 0.0, this.cameraOk = false, this.microphoneOk = false, this.monitoring = false, this.statusReason = '', this.latestSnapshotUrl, this.lastAnalyzedAt,  List<AlertSummary> recentAlerts = const <AlertSummary>[]}): _recentAlerts = recentAlerts,super._();
  

@override final  Hive hive;
@override@JsonKey() final  double persistenceRatio;
@override@JsonKey() final  double growthPerSecond;
@override@JsonKey() final  bool cameraOk;
@override@JsonKey() final  bool microphoneOk;
@override@JsonKey() final  bool monitoring;
@override@JsonKey() final  String statusReason;
@override final  String? latestSnapshotUrl;
@override final  DateTime? lastAnalyzedAt;
 final  List<AlertSummary> _recentAlerts;
@override@JsonKey() List<AlertSummary> get recentAlerts {
  if (_recentAlerts is EqualUnmodifiableListView) return _recentAlerts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentAlerts);
}


/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HiveDetailCopyWith<_HiveDetail> get copyWith => __$HiveDetailCopyWithImpl<_HiveDetail>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HiveDetail&&(identical(other.hive, hive) || other.hive == hive)&&(identical(other.persistenceRatio, persistenceRatio) || other.persistenceRatio == persistenceRatio)&&(identical(other.growthPerSecond, growthPerSecond) || other.growthPerSecond == growthPerSecond)&&(identical(other.cameraOk, cameraOk) || other.cameraOk == cameraOk)&&(identical(other.microphoneOk, microphoneOk) || other.microphoneOk == microphoneOk)&&(identical(other.monitoring, monitoring) || other.monitoring == monitoring)&&(identical(other.statusReason, statusReason) || other.statusReason == statusReason)&&(identical(other.latestSnapshotUrl, latestSnapshotUrl) || other.latestSnapshotUrl == latestSnapshotUrl)&&(identical(other.lastAnalyzedAt, lastAnalyzedAt) || other.lastAnalyzedAt == lastAnalyzedAt)&&const DeepCollectionEquality().equals(other.recentAlerts, _recentAlerts));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hive,persistenceRatio,growthPerSecond,cameraOk,microphoneOk,monitoring,statusReason,latestSnapshotUrl,lastAnalyzedAt,const DeepCollectionEquality().hash(_recentAlerts));
}

@override
String toString() {
    return 'HiveDetail(hive: $hive, persistenceRatio: $persistenceRatio, growthPerSecond: $growthPerSecond, cameraOk: $cameraOk, microphoneOk: $microphoneOk, monitoring: $monitoring, statusReason: $statusReason, latestSnapshotUrl: $latestSnapshotUrl, lastAnalyzedAt: $lastAnalyzedAt, recentAlerts: $recentAlerts)';
}


}

/// @nodoc
abstract mixin class _$HiveDetailCopyWith<$Res> implements $HiveDetailCopyWith<$Res> {
  factory _$HiveDetailCopyWith(_HiveDetail value, $Res Function(_HiveDetail) _then) = __$HiveDetailCopyWithImpl;
@override @useResult
$Res call({
 Hive hive, double persistenceRatio, double growthPerSecond, bool cameraOk, bool microphoneOk, bool monitoring, String statusReason, String? latestSnapshotUrl, DateTime? lastAnalyzedAt, List<AlertSummary> recentAlerts
});


@override $HiveCopyWith<$Res> get hive;

}
/// @nodoc
class __$HiveDetailCopyWithImpl<$Res>
    implements _$HiveDetailCopyWith<$Res> {
  __$HiveDetailCopyWithImpl(this._self, this._then);

  final _HiveDetail _self;
  final $Res Function(_HiveDetail) _then;

/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hive = null,Object? persistenceRatio = null,Object? growthPerSecond = null,Object? cameraOk = null,Object? microphoneOk = null,Object? monitoring = null,Object? statusReason = null,Object? latestSnapshotUrl = freezed,Object? lastAnalyzedAt = freezed,Object? recentAlerts = null,}) {
  return _then(_HiveDetail(
hive: null == hive ? _self.hive : hive // ignore: cast_nullable_to_non_nullable
as Hive,persistenceRatio: null == persistenceRatio ? _self.persistenceRatio : persistenceRatio // ignore: cast_nullable_to_non_nullable
as double,growthPerSecond: null == growthPerSecond ? _self.growthPerSecond : growthPerSecond // ignore: cast_nullable_to_non_nullable
as double,cameraOk: null == cameraOk ? _self.cameraOk : cameraOk // ignore: cast_nullable_to_non_nullable
as bool,microphoneOk: null == microphoneOk ? _self.microphoneOk : microphoneOk // ignore: cast_nullable_to_non_nullable
as bool,monitoring: null == monitoring ? _self.monitoring : monitoring // ignore: cast_nullable_to_non_nullable
as bool,statusReason: null == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String,latestSnapshotUrl: freezed == latestSnapshotUrl ? _self.latestSnapshotUrl : latestSnapshotUrl // ignore: cast_nullable_to_non_nullable
as String?,lastAnalyzedAt: freezed == lastAnalyzedAt ? _self.lastAnalyzedAt : lastAnalyzedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recentAlerts: null == recentAlerts ? _self._recentAlerts : recentAlerts // ignore: cast_nullable_to_non_nullable
as List<AlertSummary>,
  ));
}

/// Create a copy of HiveDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HiveCopyWith<$Res> get hive {
  
  return $HiveCopyWith<$Res>(_self.hive, (value) {
    return _then(_self.copyWith(hive: value));
  });
}
}

/// @nodoc
mixin _$DashboardSummary {

 int get total; int get normal; int get caution; int get danger; int get offline; List<Hive> get hives; List<AlertSummary> get recentAlerts;
/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardSummaryCopyWith<DashboardSummary> get copyWith => _$DashboardSummaryCopyWithImpl<DashboardSummary>(this as DashboardSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DashboardSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardSummary&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.normal, _this.normal) || other.normal == _this.normal)&&(identical(other.caution, _this.caution) || other.caution == _this.caution)&&(identical(other.danger, _this.danger) || other.danger == _this.danger)&&(identical(other.offline, _this.offline) || other.offline == _this.offline)&&const DeepCollectionEquality().equals(other.hives, _this.hives)&&const DeepCollectionEquality().equals(other.recentAlerts, _this.recentAlerts));
}


@override
int get hashCode {
  final _this = this as DashboardSummary;
  return Object.hash(runtimeType,_this.total,_this.normal,_this.caution,_this.danger,_this.offline,const DeepCollectionEquality().hash(_this.hives),const DeepCollectionEquality().hash(_this.recentAlerts));
}

@override
String toString() {
  final _this = this as DashboardSummary;
  return 'DashboardSummary(total: ${_this.total}, normal: ${_this.normal}, caution: ${_this.caution}, danger: ${_this.danger}, offline: ${_this.offline}, hives: ${_this.hives}, recentAlerts: ${_this.recentAlerts})';
}


}

/// @nodoc
abstract mixin class $DashboardSummaryCopyWith<$Res>  {
  factory $DashboardSummaryCopyWith(DashboardSummary value, $Res Function(DashboardSummary) _then) = _$DashboardSummaryCopyWithImpl;
@useResult
$Res call({
 int total, int normal, int caution, int danger, int offline, List<Hive> hives, List<AlertSummary> recentAlerts
});




}
/// @nodoc
class _$DashboardSummaryCopyWithImpl<$Res>
    implements $DashboardSummaryCopyWith<$Res> {
  _$DashboardSummaryCopyWithImpl(this._self, this._then);

  final DashboardSummary _self;
  final $Res Function(DashboardSummary) _then;

/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? normal = null,Object? caution = null,Object? danger = null,Object? offline = null,Object? hives = null,Object? recentAlerts = null,}) {
  return _then(DashboardSummary(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,normal: null == normal ? _self.normal : normal // ignore: cast_nullable_to_non_nullable
as int,caution: null == caution ? _self.caution : caution // ignore: cast_nullable_to_non_nullable
as int,danger: null == danger ? _self.danger : danger // ignore: cast_nullable_to_non_nullable
as int,offline: null == offline ? _self.offline : offline // ignore: cast_nullable_to_non_nullable
as int,hives: null == hives ? _self.hives : hives // ignore: cast_nullable_to_non_nullable
as List<Hive>,recentAlerts: null == recentAlerts ? _self.recentAlerts : recentAlerts // ignore: cast_nullable_to_non_nullable
as List<AlertSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardSummary].
extension DashboardSummaryPatterns on DashboardSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardSummary value)  $default,){
final _that = this;
switch (_that) {
case _DashboardSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int normal,  int caution,  int danger,  int offline,  List<Hive> hives,  List<AlertSummary> recentAlerts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that.total,_that.normal,_that.caution,_that.danger,_that.offline,_that.hives,_that.recentAlerts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int normal,  int caution,  int danger,  int offline,  List<Hive> hives,  List<AlertSummary> recentAlerts)  $default,) {final _that = this;
switch (_that) {
case _DashboardSummary():
return $default(_that.total,_that.normal,_that.caution,_that.danger,_that.offline,_that.hives,_that.recentAlerts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int normal,  int caution,  int danger,  int offline,  List<Hive> hives,  List<AlertSummary> recentAlerts)?  $default,) {final _that = this;
switch (_that) {
case _DashboardSummary() when $default != null:
return $default(_that.total,_that.normal,_that.caution,_that.danger,_that.offline,_that.hives,_that.recentAlerts);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardSummary extends DashboardSummary {
  const _DashboardSummary({this.total = 0, this.normal = 0, this.caution = 0, this.danger = 0, this.offline = 0,  List<Hive> hives = const <Hive>[],  List<AlertSummary> recentAlerts = const <AlertSummary>[]}): _hives = hives,_recentAlerts = recentAlerts,super._();
  

@override@JsonKey() final  int total;
@override@JsonKey() final  int normal;
@override@JsonKey() final  int caution;
@override@JsonKey() final  int danger;
@override@JsonKey() final  int offline;
 final  List<Hive> _hives;
@override@JsonKey() List<Hive> get hives {
  if (_hives is EqualUnmodifiableListView) return _hives;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hives);
}

 final  List<AlertSummary> _recentAlerts;
@override@JsonKey() List<AlertSummary> get recentAlerts {
  if (_recentAlerts is EqualUnmodifiableListView) return _recentAlerts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentAlerts);
}


/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardSummaryCopyWith<_DashboardSummary> get copyWith => __$DashboardSummaryCopyWithImpl<_DashboardSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardSummary&&(identical(other.total, total) || other.total == total)&&(identical(other.normal, normal) || other.normal == normal)&&(identical(other.caution, caution) || other.caution == caution)&&(identical(other.danger, danger) || other.danger == danger)&&(identical(other.offline, offline) || other.offline == offline)&&const DeepCollectionEquality().equals(other.hives, _hives)&&const DeepCollectionEquality().equals(other.recentAlerts, _recentAlerts));
}


@override
int get hashCode {
    return Object.hash(runtimeType,total,normal,caution,danger,offline,const DeepCollectionEquality().hash(_hives),const DeepCollectionEquality().hash(_recentAlerts));
}

@override
String toString() {
    return 'DashboardSummary(total: $total, normal: $normal, caution: $caution, danger: $danger, offline: $offline, hives: $hives, recentAlerts: $recentAlerts)';
}


}

/// @nodoc
abstract mixin class _$DashboardSummaryCopyWith<$Res> implements $DashboardSummaryCopyWith<$Res> {
  factory _$DashboardSummaryCopyWith(_DashboardSummary value, $Res Function(_DashboardSummary) _then) = __$DashboardSummaryCopyWithImpl;
@override @useResult
$Res call({
 int total, int normal, int caution, int danger, int offline, List<Hive> hives, List<AlertSummary> recentAlerts
});




}
/// @nodoc
class __$DashboardSummaryCopyWithImpl<$Res>
    implements _$DashboardSummaryCopyWith<$Res> {
  __$DashboardSummaryCopyWithImpl(this._self, this._then);

  final _DashboardSummary _self;
  final $Res Function(_DashboardSummary) _then;

/// Create a copy of DashboardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? normal = null,Object? caution = null,Object? danger = null,Object? offline = null,Object? hives = null,Object? recentAlerts = null,}) {
  return _then(_DashboardSummary(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,normal: null == normal ? _self.normal : normal // ignore: cast_nullable_to_non_nullable
as int,caution: null == caution ? _self.caution : caution // ignore: cast_nullable_to_non_nullable
as int,danger: null == danger ? _self.danger : danger // ignore: cast_nullable_to_non_nullable
as int,offline: null == offline ? _self.offline : offline // ignore: cast_nullable_to_non_nullable
as int,hives: null == hives ? _self._hives : hives // ignore: cast_nullable_to_non_nullable
as List<Hive>,recentAlerts: null == recentAlerts ? _self._recentAlerts : recentAlerts // ignore: cast_nullable_to_non_nullable
as List<AlertSummary>,
  ));
}


}

/// @nodoc
mixin _$HiveStatusSnapshot {

 String get hiveId; HiveStatus get status; int get riskScore; int get hornetCount; int get maxHornetCount; double get audioProbability; bool get monitoringOnline; String get statusReason; DateTime? get lastHeartbeat; DateTime? get lastAnalyzedAt;
/// Create a copy of HiveStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HiveStatusSnapshotCopyWith<HiveStatusSnapshot> get copyWith => _$HiveStatusSnapshotCopyWithImpl<HiveStatusSnapshot>(this as HiveStatusSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HiveStatusSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HiveStatusSnapshot&&(identical(other.hiveId, _this.hiveId) || other.hiveId == _this.hiveId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.riskScore, _this.riskScore) || other.riskScore == _this.riskScore)&&(identical(other.hornetCount, _this.hornetCount) || other.hornetCount == _this.hornetCount)&&(identical(other.maxHornetCount, _this.maxHornetCount) || other.maxHornetCount == _this.maxHornetCount)&&(identical(other.audioProbability, _this.audioProbability) || other.audioProbability == _this.audioProbability)&&(identical(other.monitoringOnline, _this.monitoringOnline) || other.monitoringOnline == _this.monitoringOnline)&&(identical(other.statusReason, _this.statusReason) || other.statusReason == _this.statusReason)&&(identical(other.lastHeartbeat, _this.lastHeartbeat) || other.lastHeartbeat == _this.lastHeartbeat)&&(identical(other.lastAnalyzedAt, _this.lastAnalyzedAt) || other.lastAnalyzedAt == _this.lastAnalyzedAt));
}


@override
int get hashCode {
  final _this = this as HiveStatusSnapshot;
  return Object.hash(runtimeType,_this.hiveId,_this.status,_this.riskScore,_this.hornetCount,_this.maxHornetCount,_this.audioProbability,_this.monitoringOnline,_this.statusReason,_this.lastHeartbeat,_this.lastAnalyzedAt);
}

@override
String toString() {
  final _this = this as HiveStatusSnapshot;
  return 'HiveStatusSnapshot(hiveId: ${_this.hiveId}, status: ${_this.status}, riskScore: ${_this.riskScore}, hornetCount: ${_this.hornetCount}, maxHornetCount: ${_this.maxHornetCount}, audioProbability: ${_this.audioProbability}, monitoringOnline: ${_this.monitoringOnline}, statusReason: ${_this.statusReason}, lastHeartbeat: ${_this.lastHeartbeat}, lastAnalyzedAt: ${_this.lastAnalyzedAt})';
}


}

/// @nodoc
abstract mixin class $HiveStatusSnapshotCopyWith<$Res>  {
  factory $HiveStatusSnapshotCopyWith(HiveStatusSnapshot value, $Res Function(HiveStatusSnapshot) _then) = _$HiveStatusSnapshotCopyWithImpl;
@useResult
$Res call({
 String hiveId, HiveStatus status, int riskScore, int hornetCount, int maxHornetCount, double audioProbability, bool monitoringOnline, String statusReason, DateTime? lastHeartbeat, DateTime? lastAnalyzedAt
});




}
/// @nodoc
class _$HiveStatusSnapshotCopyWithImpl<$Res>
    implements $HiveStatusSnapshotCopyWith<$Res> {
  _$HiveStatusSnapshotCopyWithImpl(this._self, this._then);

  final HiveStatusSnapshot _self;
  final $Res Function(HiveStatusSnapshot) _then;

/// Create a copy of HiveStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hiveId = null,Object? status = null,Object? riskScore = null,Object? hornetCount = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? monitoringOnline = null,Object? statusReason = null,Object? lastHeartbeat = freezed,Object? lastAnalyzedAt = freezed,}) {
  return _then(HiveStatusSnapshot(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,monitoringOnline: null == monitoringOnline ? _self.monitoringOnline : monitoringOnline // ignore: cast_nullable_to_non_nullable
as bool,statusReason: null == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String,lastHeartbeat: freezed == lastHeartbeat ? _self.lastHeartbeat : lastHeartbeat // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAnalyzedAt: freezed == lastAnalyzedAt ? _self.lastAnalyzedAt : lastAnalyzedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HiveStatusSnapshot].
extension HiveStatusSnapshotPatterns on HiveStatusSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HiveStatusSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HiveStatusSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HiveStatusSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _HiveStatusSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HiveStatusSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _HiveStatusSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hiveId,  HiveStatus status,  int riskScore,  int hornetCount,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  String statusReason,  DateTime? lastHeartbeat,  DateTime? lastAnalyzedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HiveStatusSnapshot() when $default != null:
return $default(_that.hiveId,_that.status,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.statusReason,_that.lastHeartbeat,_that.lastAnalyzedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hiveId,  HiveStatus status,  int riskScore,  int hornetCount,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  String statusReason,  DateTime? lastHeartbeat,  DateTime? lastAnalyzedAt)  $default,) {final _that = this;
switch (_that) {
case _HiveStatusSnapshot():
return $default(_that.hiveId,_that.status,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.statusReason,_that.lastHeartbeat,_that.lastAnalyzedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hiveId,  HiveStatus status,  int riskScore,  int hornetCount,  int maxHornetCount,  double audioProbability,  bool monitoringOnline,  String statusReason,  DateTime? lastHeartbeat,  DateTime? lastAnalyzedAt)?  $default,) {final _that = this;
switch (_that) {
case _HiveStatusSnapshot() when $default != null:
return $default(_that.hiveId,_that.status,_that.riskScore,_that.hornetCount,_that.maxHornetCount,_that.audioProbability,_that.monitoringOnline,_that.statusReason,_that.lastHeartbeat,_that.lastAnalyzedAt);case _:
  return null;

}
}

}

/// @nodoc


class _HiveStatusSnapshot extends HiveStatusSnapshot {
  const _HiveStatusSnapshot({required this.hiveId, required this.status, this.riskScore = 0, this.hornetCount = 0, this.maxHornetCount = 0, this.audioProbability = 0.0, this.monitoringOnline = false, this.statusReason = '', this.lastHeartbeat, this.lastAnalyzedAt}): super._();
  

@override final  String hiveId;
@override final  HiveStatus status;
@override@JsonKey() final  int riskScore;
@override@JsonKey() final  int hornetCount;
@override@JsonKey() final  int maxHornetCount;
@override@JsonKey() final  double audioProbability;
@override@JsonKey() final  bool monitoringOnline;
@override@JsonKey() final  String statusReason;
@override final  DateTime? lastHeartbeat;
@override final  DateTime? lastAnalyzedAt;

/// Create a copy of HiveStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HiveStatusSnapshotCopyWith<_HiveStatusSnapshot> get copyWith => __$HiveStatusSnapshotCopyWithImpl<_HiveStatusSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HiveStatusSnapshot&&(identical(other.hiveId, hiveId) || other.hiveId == hiveId)&&(identical(other.status, status) || other.status == status)&&(identical(other.riskScore, riskScore) || other.riskScore == riskScore)&&(identical(other.hornetCount, hornetCount) || other.hornetCount == hornetCount)&&(identical(other.maxHornetCount, maxHornetCount) || other.maxHornetCount == maxHornetCount)&&(identical(other.audioProbability, audioProbability) || other.audioProbability == audioProbability)&&(identical(other.monitoringOnline, monitoringOnline) || other.monitoringOnline == monitoringOnline)&&(identical(other.statusReason, statusReason) || other.statusReason == statusReason)&&(identical(other.lastHeartbeat, lastHeartbeat) || other.lastHeartbeat == lastHeartbeat)&&(identical(other.lastAnalyzedAt, lastAnalyzedAt) || other.lastAnalyzedAt == lastAnalyzedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hiveId,status,riskScore,hornetCount,maxHornetCount,audioProbability,monitoringOnline,statusReason,lastHeartbeat,lastAnalyzedAt);
}

@override
String toString() {
    return 'HiveStatusSnapshot(hiveId: $hiveId, status: $status, riskScore: $riskScore, hornetCount: $hornetCount, maxHornetCount: $maxHornetCount, audioProbability: $audioProbability, monitoringOnline: $monitoringOnline, statusReason: $statusReason, lastHeartbeat: $lastHeartbeat, lastAnalyzedAt: $lastAnalyzedAt)';
}


}

/// @nodoc
abstract mixin class _$HiveStatusSnapshotCopyWith<$Res> implements $HiveStatusSnapshotCopyWith<$Res> {
  factory _$HiveStatusSnapshotCopyWith(_HiveStatusSnapshot value, $Res Function(_HiveStatusSnapshot) _then) = __$HiveStatusSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String hiveId, HiveStatus status, int riskScore, int hornetCount, int maxHornetCount, double audioProbability, bool monitoringOnline, String statusReason, DateTime? lastHeartbeat, DateTime? lastAnalyzedAt
});




}
/// @nodoc
class __$HiveStatusSnapshotCopyWithImpl<$Res>
    implements _$HiveStatusSnapshotCopyWith<$Res> {
  __$HiveStatusSnapshotCopyWithImpl(this._self, this._then);

  final _HiveStatusSnapshot _self;
  final $Res Function(_HiveStatusSnapshot) _then;

/// Create a copy of HiveStatusSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hiveId = null,Object? status = null,Object? riskScore = null,Object? hornetCount = null,Object? maxHornetCount = null,Object? audioProbability = null,Object? monitoringOnline = null,Object? statusReason = null,Object? lastHeartbeat = freezed,Object? lastAnalyzedAt = freezed,}) {
  return _then(_HiveStatusSnapshot(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HiveStatus,riskScore: null == riskScore ? _self.riskScore : riskScore // ignore: cast_nullable_to_non_nullable
as int,hornetCount: null == hornetCount ? _self.hornetCount : hornetCount // ignore: cast_nullable_to_non_nullable
as int,maxHornetCount: null == maxHornetCount ? _self.maxHornetCount : maxHornetCount // ignore: cast_nullable_to_non_nullable
as int,audioProbability: null == audioProbability ? _self.audioProbability : audioProbability // ignore: cast_nullable_to_non_nullable
as double,monitoringOnline: null == monitoringOnline ? _self.monitoringOnline : monitoringOnline // ignore: cast_nullable_to_non_nullable
as bool,statusReason: null == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String,lastHeartbeat: freezed == lastHeartbeat ? _self.lastHeartbeat : lastHeartbeat // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAnalyzedAt: freezed == lastAnalyzedAt ? _self.lastAnalyzedAt : lastAnalyzedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
