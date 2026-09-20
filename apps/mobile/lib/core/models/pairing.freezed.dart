// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pairing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PairingSession {

 String get id; String get code; String get hiveId; DateTime get expiresAt; String get hiveName; PairingStatus get status; int get expiresInSeconds; String get pairUri; String? get claimedDeviceId;
/// Create a copy of PairingSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingSessionCopyWith<PairingSession> get copyWith => _$PairingSessionCopyWithImpl<PairingSession>(this as PairingSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PairingSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.hiveId, _this.hiveId) || other.hiveId == _this.hiveId)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.hiveName, _this.hiveName) || other.hiveName == _this.hiveName)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.expiresInSeconds, _this.expiresInSeconds) || other.expiresInSeconds == _this.expiresInSeconds)&&(identical(other.pairUri, _this.pairUri) || other.pairUri == _this.pairUri)&&(identical(other.claimedDeviceId, _this.claimedDeviceId) || other.claimedDeviceId == _this.claimedDeviceId));
}


@override
int get hashCode {
  final _this = this as PairingSession;
  return Object.hash(runtimeType,_this.id,_this.code,_this.hiveId,_this.expiresAt,_this.hiveName,_this.status,_this.expiresInSeconds,_this.pairUri,_this.claimedDeviceId);
}

@override
String toString() {
  final _this = this as PairingSession;
  return 'PairingSession(id: ${_this.id}, code: ${_this.code}, hiveId: ${_this.hiveId}, expiresAt: ${_this.expiresAt}, hiveName: ${_this.hiveName}, status: ${_this.status}, expiresInSeconds: ${_this.expiresInSeconds}, pairUri: ${_this.pairUri}, claimedDeviceId: ${_this.claimedDeviceId})';
}


}

/// @nodoc
abstract mixin class $PairingSessionCopyWith<$Res>  {
  factory $PairingSessionCopyWith(PairingSession value, $Res Function(PairingSession) _then) = _$PairingSessionCopyWithImpl;
@useResult
$Res call({
 String id, String code, String hiveId, DateTime expiresAt, String hiveName, PairingStatus status, int expiresInSeconds, String pairUri, String? claimedDeviceId
});




}
/// @nodoc
class _$PairingSessionCopyWithImpl<$Res>
    implements $PairingSessionCopyWith<$Res> {
  _$PairingSessionCopyWithImpl(this._self, this._then);

  final PairingSession _self;
  final $Res Function(PairingSession) _then;

/// Create a copy of PairingSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? hiveId = null,Object? expiresAt = null,Object? hiveName = null,Object? status = null,Object? expiresInSeconds = null,Object? pairUri = null,Object? claimedDeviceId = freezed,}) {
  return _then(PairingSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PairingStatus,expiresInSeconds: null == expiresInSeconds ? _self.expiresInSeconds : expiresInSeconds // ignore: cast_nullable_to_non_nullable
as int,pairUri: null == pairUri ? _self.pairUri : pairUri // ignore: cast_nullable_to_non_nullable
as String,claimedDeviceId: freezed == claimedDeviceId ? _self.claimedDeviceId : claimedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PairingSession].
extension PairingSessionPatterns on PairingSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairingSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairingSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairingSession value)  $default,){
final _that = this;
switch (_that) {
case _PairingSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairingSession value)?  $default,){
final _that = this;
switch (_that) {
case _PairingSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String hiveId,  DateTime expiresAt,  String hiveName,  PairingStatus status,  int expiresInSeconds,  String pairUri,  String? claimedDeviceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairingSession() when $default != null:
return $default(_that.id,_that.code,_that.hiveId,_that.expiresAt,_that.hiveName,_that.status,_that.expiresInSeconds,_that.pairUri,_that.claimedDeviceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String hiveId,  DateTime expiresAt,  String hiveName,  PairingStatus status,  int expiresInSeconds,  String pairUri,  String? claimedDeviceId)  $default,) {final _that = this;
switch (_that) {
case _PairingSession():
return $default(_that.id,_that.code,_that.hiveId,_that.expiresAt,_that.hiveName,_that.status,_that.expiresInSeconds,_that.pairUri,_that.claimedDeviceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String hiveId,  DateTime expiresAt,  String hiveName,  PairingStatus status,  int expiresInSeconds,  String pairUri,  String? claimedDeviceId)?  $default,) {final _that = this;
switch (_that) {
case _PairingSession() when $default != null:
return $default(_that.id,_that.code,_that.hiveId,_that.expiresAt,_that.hiveName,_that.status,_that.expiresInSeconds,_that.pairUri,_that.claimedDeviceId);case _:
  return null;

}
}

}

/// @nodoc


class _PairingSession extends PairingSession {
  const _PairingSession({required this.id, required this.code, required this.hiveId, required this.expiresAt, this.hiveName = '', this.status = PairingStatus.waiting, this.expiresInSeconds = 0, this.pairUri = '', this.claimedDeviceId}): super._();
  

@override final  String id;
@override final  String code;
@override final  String hiveId;
@override final  DateTime expiresAt;
@override@JsonKey() final  String hiveName;
@override@JsonKey() final  PairingStatus status;
@override@JsonKey() final  int expiresInSeconds;
@override@JsonKey() final  String pairUri;
@override final  String? claimedDeviceId;

/// Create a copy of PairingSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairingSessionCopyWith<_PairingSession> get copyWith => __$PairingSessionCopyWithImpl<_PairingSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairingSession&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.hiveId, hiveId) || other.hiveId == hiveId)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.hiveName, hiveName) || other.hiveName == hiveName)&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresInSeconds, expiresInSeconds) || other.expiresInSeconds == expiresInSeconds)&&(identical(other.pairUri, pairUri) || other.pairUri == pairUri)&&(identical(other.claimedDeviceId, claimedDeviceId) || other.claimedDeviceId == claimedDeviceId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,code,hiveId,expiresAt,hiveName,status,expiresInSeconds,pairUri,claimedDeviceId);
}

@override
String toString() {
    return 'PairingSession(id: $id, code: $code, hiveId: $hiveId, expiresAt: $expiresAt, hiveName: $hiveName, status: $status, expiresInSeconds: $expiresInSeconds, pairUri: $pairUri, claimedDeviceId: $claimedDeviceId)';
}


}

/// @nodoc
abstract mixin class _$PairingSessionCopyWith<$Res> implements $PairingSessionCopyWith<$Res> {
  factory _$PairingSessionCopyWith(_PairingSession value, $Res Function(_PairingSession) _then) = __$PairingSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String hiveId, DateTime expiresAt, String hiveName, PairingStatus status, int expiresInSeconds, String pairUri, String? claimedDeviceId
});




}
/// @nodoc
class __$PairingSessionCopyWithImpl<$Res>
    implements _$PairingSessionCopyWith<$Res> {
  __$PairingSessionCopyWithImpl(this._self, this._then);

  final _PairingSession _self;
  final $Res Function(_PairingSession) _then;

/// Create a copy of PairingSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? hiveId = null,Object? expiresAt = null,Object? hiveName = null,Object? status = null,Object? expiresInSeconds = null,Object? pairUri = null,Object? claimedDeviceId = freezed,}) {
  return _then(_PairingSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PairingStatus,expiresInSeconds: null == expiresInSeconds ? _self.expiresInSeconds : expiresInSeconds // ignore: cast_nullable_to_non_nullable
as int,pairUri: null == pairUri ? _self.pairUri : pairUri // ignore: cast_nullable_to_non_nullable
as String,claimedDeviceId: freezed == claimedDeviceId ? _self.claimedDeviceId : claimedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PairedHive {

 String get hiveId; String get hiveName; String get deviceId; String get pairingId;
/// Create a copy of PairedHive
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairedHiveCopyWith<PairedHive> get copyWith => _$PairedHiveCopyWithImpl<PairedHive>(this as PairedHive, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PairedHive;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairedHive&&(identical(other.hiveId, _this.hiveId) || other.hiveId == _this.hiveId)&&(identical(other.hiveName, _this.hiveName) || other.hiveName == _this.hiveName)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.pairingId, _this.pairingId) || other.pairingId == _this.pairingId));
}


@override
int get hashCode {
  final _this = this as PairedHive;
  return Object.hash(runtimeType,_this.hiveId,_this.hiveName,_this.deviceId,_this.pairingId);
}

@override
String toString() {
  final _this = this as PairedHive;
  return 'PairedHive(hiveId: ${_this.hiveId}, hiveName: ${_this.hiveName}, deviceId: ${_this.deviceId}, pairingId: ${_this.pairingId})';
}


}

/// @nodoc
abstract mixin class $PairedHiveCopyWith<$Res>  {
  factory $PairedHiveCopyWith(PairedHive value, $Res Function(PairedHive) _then) = _$PairedHiveCopyWithImpl;
@useResult
$Res call({
 String hiveId, String hiveName, String deviceId, String pairingId
});




}
/// @nodoc
class _$PairedHiveCopyWithImpl<$Res>
    implements $PairedHiveCopyWith<$Res> {
  _$PairedHiveCopyWithImpl(this._self, this._then);

  final PairedHive _self;
  final $Res Function(PairedHive) _then;

/// Create a copy of PairedHive
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hiveId = null,Object? hiveName = null,Object? deviceId = null,Object? pairingId = null,}) {
  return _then(PairedHive(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,pairingId: null == pairingId ? _self.pairingId : pairingId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PairedHive].
extension PairedHivePatterns on PairedHive {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairedHive value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairedHive() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairedHive value)  $default,){
final _that = this;
switch (_that) {
case _PairedHive():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairedHive value)?  $default,){
final _that = this;
switch (_that) {
case _PairedHive() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hiveId,  String hiveName,  String deviceId,  String pairingId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairedHive() when $default != null:
return $default(_that.hiveId,_that.hiveName,_that.deviceId,_that.pairingId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hiveId,  String hiveName,  String deviceId,  String pairingId)  $default,) {final _that = this;
switch (_that) {
case _PairedHive():
return $default(_that.hiveId,_that.hiveName,_that.deviceId,_that.pairingId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hiveId,  String hiveName,  String deviceId,  String pairingId)?  $default,) {final _that = this;
switch (_that) {
case _PairedHive() when $default != null:
return $default(_that.hiveId,_that.hiveName,_that.deviceId,_that.pairingId);case _:
  return null;

}
}

}

/// @nodoc


class _PairedHive extends PairedHive {
  const _PairedHive({required this.hiveId, required this.hiveName, this.deviceId = '', this.pairingId = ''}): super._();
  

@override final  String hiveId;
@override final  String hiveName;
@override@JsonKey() final  String deviceId;
@override@JsonKey() final  String pairingId;

/// Create a copy of PairedHive
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairedHiveCopyWith<_PairedHive> get copyWith => __$PairedHiveCopyWithImpl<_PairedHive>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairedHive&&(identical(other.hiveId, hiveId) || other.hiveId == hiveId)&&(identical(other.hiveName, hiveName) || other.hiveName == hiveName)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.pairingId, pairingId) || other.pairingId == pairingId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hiveId,hiveName,deviceId,pairingId);
}

@override
String toString() {
    return 'PairedHive(hiveId: $hiveId, hiveName: $hiveName, deviceId: $deviceId, pairingId: $pairingId)';
}


}

/// @nodoc
abstract mixin class _$PairedHiveCopyWith<$Res> implements $PairedHiveCopyWith<$Res> {
  factory _$PairedHiveCopyWith(_PairedHive value, $Res Function(_PairedHive) _then) = __$PairedHiveCopyWithImpl;
@override @useResult
$Res call({
 String hiveId, String hiveName, String deviceId, String pairingId
});




}
/// @nodoc
class __$PairedHiveCopyWithImpl<$Res>
    implements _$PairedHiveCopyWith<$Res> {
  __$PairedHiveCopyWithImpl(this._self, this._then);

  final _PairedHive _self;
  final $Res Function(_PairedHive) _then;

/// Create a copy of PairedHive
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hiveId = null,Object? hiveName = null,Object? deviceId = null,Object? pairingId = null,}) {
  return _then(_PairedHive(
hiveId: null == hiveId ? _self.hiveId : hiveId // ignore: cast_nullable_to_non_nullable
as String,hiveName: null == hiveName ? _self.hiveName : hiveName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,pairingId: null == pairingId ? _self.pairingId : pairingId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
