// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referral_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReferralStats {

 String get referralCode; String get referralLink; int get rewardAmount; int get referralLimit; int get remainingReferrals; int get referralCount; int get totalReferralEarnings; int get totalInvited; int get creditedCount; int get pendingCount; int get rejectedCount; String get rewardCondition; List<InvitedPartner> get invitedPartners;
/// Create a copy of ReferralStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferralStatsCopyWith<ReferralStats> get copyWith => _$ReferralStatsCopyWithImpl<ReferralStats>(this as ReferralStats, _$identity);

  /// Serializes this ReferralStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferralStats&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.referralLink, referralLink) || other.referralLink == referralLink)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.referralLimit, referralLimit) || other.referralLimit == referralLimit)&&(identical(other.remainingReferrals, remainingReferrals) || other.remainingReferrals == remainingReferrals)&&(identical(other.referralCount, referralCount) || other.referralCount == referralCount)&&(identical(other.totalReferralEarnings, totalReferralEarnings) || other.totalReferralEarnings == totalReferralEarnings)&&(identical(other.totalInvited, totalInvited) || other.totalInvited == totalInvited)&&(identical(other.creditedCount, creditedCount) || other.creditedCount == creditedCount)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount)&&(identical(other.rejectedCount, rejectedCount) || other.rejectedCount == rejectedCount)&&(identical(other.rewardCondition, rewardCondition) || other.rewardCondition == rewardCondition)&&const DeepCollectionEquality().equals(other.invitedPartners, invitedPartners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,referralCode,referralLink,rewardAmount,referralLimit,remainingReferrals,referralCount,totalReferralEarnings,totalInvited,creditedCount,pendingCount,rejectedCount,rewardCondition,const DeepCollectionEquality().hash(invitedPartners));

@override
String toString() {
  return 'ReferralStats(referralCode: $referralCode, referralLink: $referralLink, rewardAmount: $rewardAmount, referralLimit: $referralLimit, remainingReferrals: $remainingReferrals, referralCount: $referralCount, totalReferralEarnings: $totalReferralEarnings, totalInvited: $totalInvited, creditedCount: $creditedCount, pendingCount: $pendingCount, rejectedCount: $rejectedCount, rewardCondition: $rewardCondition, invitedPartners: $invitedPartners)';
}


}

/// @nodoc
abstract mixin class $ReferralStatsCopyWith<$Res>  {
  factory $ReferralStatsCopyWith(ReferralStats value, $Res Function(ReferralStats) _then) = _$ReferralStatsCopyWithImpl;
@useResult
$Res call({
 String referralCode, String referralLink, int rewardAmount, int referralLimit, int remainingReferrals, int referralCount, int totalReferralEarnings, int totalInvited, int creditedCount, int pendingCount, int rejectedCount, String rewardCondition, List<InvitedPartner> invitedPartners
});




}
/// @nodoc
class _$ReferralStatsCopyWithImpl<$Res>
    implements $ReferralStatsCopyWith<$Res> {
  _$ReferralStatsCopyWithImpl(this._self, this._then);

  final ReferralStats _self;
  final $Res Function(ReferralStats) _then;

/// Create a copy of ReferralStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? referralCode = null,Object? referralLink = null,Object? rewardAmount = null,Object? referralLimit = null,Object? remainingReferrals = null,Object? referralCount = null,Object? totalReferralEarnings = null,Object? totalInvited = null,Object? creditedCount = null,Object? pendingCount = null,Object? rejectedCount = null,Object? rewardCondition = null,Object? invitedPartners = null,}) {
  return _then(_self.copyWith(
referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referralLink: null == referralLink ? _self.referralLink : referralLink // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as int,referralLimit: null == referralLimit ? _self.referralLimit : referralLimit // ignore: cast_nullable_to_non_nullable
as int,remainingReferrals: null == remainingReferrals ? _self.remainingReferrals : remainingReferrals // ignore: cast_nullable_to_non_nullable
as int,referralCount: null == referralCount ? _self.referralCount : referralCount // ignore: cast_nullable_to_non_nullable
as int,totalReferralEarnings: null == totalReferralEarnings ? _self.totalReferralEarnings : totalReferralEarnings // ignore: cast_nullable_to_non_nullable
as int,totalInvited: null == totalInvited ? _self.totalInvited : totalInvited // ignore: cast_nullable_to_non_nullable
as int,creditedCount: null == creditedCount ? _self.creditedCount : creditedCount // ignore: cast_nullable_to_non_nullable
as int,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,rejectedCount: null == rejectedCount ? _self.rejectedCount : rejectedCount // ignore: cast_nullable_to_non_nullable
as int,rewardCondition: null == rewardCondition ? _self.rewardCondition : rewardCondition // ignore: cast_nullable_to_non_nullable
as String,invitedPartners: null == invitedPartners ? _self.invitedPartners : invitedPartners // ignore: cast_nullable_to_non_nullable
as List<InvitedPartner>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferralStats].
extension ReferralStatsPatterns on ReferralStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferralStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferralStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferralStats value)  $default,){
final _that = this;
switch (_that) {
case _ReferralStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferralStats value)?  $default,){
final _that = this;
switch (_that) {
case _ReferralStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String referralCode,  String referralLink,  int rewardAmount,  int referralLimit,  int remainingReferrals,  int referralCount,  int totalReferralEarnings,  int totalInvited,  int creditedCount,  int pendingCount,  int rejectedCount,  String rewardCondition,  List<InvitedPartner> invitedPartners)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferralStats() when $default != null:
return $default(_that.referralCode,_that.referralLink,_that.rewardAmount,_that.referralLimit,_that.remainingReferrals,_that.referralCount,_that.totalReferralEarnings,_that.totalInvited,_that.creditedCount,_that.pendingCount,_that.rejectedCount,_that.rewardCondition,_that.invitedPartners);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String referralCode,  String referralLink,  int rewardAmount,  int referralLimit,  int remainingReferrals,  int referralCount,  int totalReferralEarnings,  int totalInvited,  int creditedCount,  int pendingCount,  int rejectedCount,  String rewardCondition,  List<InvitedPartner> invitedPartners)  $default,) {final _that = this;
switch (_that) {
case _ReferralStats():
return $default(_that.referralCode,_that.referralLink,_that.rewardAmount,_that.referralLimit,_that.remainingReferrals,_that.referralCount,_that.totalReferralEarnings,_that.totalInvited,_that.creditedCount,_that.pendingCount,_that.rejectedCount,_that.rewardCondition,_that.invitedPartners);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String referralCode,  String referralLink,  int rewardAmount,  int referralLimit,  int remainingReferrals,  int referralCount,  int totalReferralEarnings,  int totalInvited,  int creditedCount,  int pendingCount,  int rejectedCount,  String rewardCondition,  List<InvitedPartner> invitedPartners)?  $default,) {final _that = this;
switch (_that) {
case _ReferralStats() when $default != null:
return $default(_that.referralCode,_that.referralLink,_that.rewardAmount,_that.referralLimit,_that.remainingReferrals,_that.referralCount,_that.totalReferralEarnings,_that.totalInvited,_that.creditedCount,_that.pendingCount,_that.rejectedCount,_that.rewardCondition,_that.invitedPartners);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReferralStats implements ReferralStats {
  const _ReferralStats({this.referralCode = '', this.referralLink = '', this.rewardAmount = 0, this.referralLimit = 0, this.remainingReferrals = 0, this.referralCount = 0, this.totalReferralEarnings = 0, this.totalInvited = 0, this.creditedCount = 0, this.pendingCount = 0, this.rejectedCount = 0, this.rewardCondition = '', final  List<InvitedPartner> invitedPartners = const []}): _invitedPartners = invitedPartners;
  factory _ReferralStats.fromJson(Map<String, dynamic> json) => _$ReferralStatsFromJson(json);

@override@JsonKey() final  String referralCode;
@override@JsonKey() final  String referralLink;
@override@JsonKey() final  int rewardAmount;
@override@JsonKey() final  int referralLimit;
@override@JsonKey() final  int remainingReferrals;
@override@JsonKey() final  int referralCount;
@override@JsonKey() final  int totalReferralEarnings;
@override@JsonKey() final  int totalInvited;
@override@JsonKey() final  int creditedCount;
@override@JsonKey() final  int pendingCount;
@override@JsonKey() final  int rejectedCount;
@override@JsonKey() final  String rewardCondition;
 final  List<InvitedPartner> _invitedPartners;
@override@JsonKey() List<InvitedPartner> get invitedPartners {
  if (_invitedPartners is EqualUnmodifiableListView) return _invitedPartners;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invitedPartners);
}


/// Create a copy of ReferralStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferralStatsCopyWith<_ReferralStats> get copyWith => __$ReferralStatsCopyWithImpl<_ReferralStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferralStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferralStats&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.referralLink, referralLink) || other.referralLink == referralLink)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.referralLimit, referralLimit) || other.referralLimit == referralLimit)&&(identical(other.remainingReferrals, remainingReferrals) || other.remainingReferrals == remainingReferrals)&&(identical(other.referralCount, referralCount) || other.referralCount == referralCount)&&(identical(other.totalReferralEarnings, totalReferralEarnings) || other.totalReferralEarnings == totalReferralEarnings)&&(identical(other.totalInvited, totalInvited) || other.totalInvited == totalInvited)&&(identical(other.creditedCount, creditedCount) || other.creditedCount == creditedCount)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount)&&(identical(other.rejectedCount, rejectedCount) || other.rejectedCount == rejectedCount)&&(identical(other.rewardCondition, rewardCondition) || other.rewardCondition == rewardCondition)&&const DeepCollectionEquality().equals(other._invitedPartners, _invitedPartners));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,referralCode,referralLink,rewardAmount,referralLimit,remainingReferrals,referralCount,totalReferralEarnings,totalInvited,creditedCount,pendingCount,rejectedCount,rewardCondition,const DeepCollectionEquality().hash(_invitedPartners));

@override
String toString() {
  return 'ReferralStats(referralCode: $referralCode, referralLink: $referralLink, rewardAmount: $rewardAmount, referralLimit: $referralLimit, remainingReferrals: $remainingReferrals, referralCount: $referralCount, totalReferralEarnings: $totalReferralEarnings, totalInvited: $totalInvited, creditedCount: $creditedCount, pendingCount: $pendingCount, rejectedCount: $rejectedCount, rewardCondition: $rewardCondition, invitedPartners: $invitedPartners)';
}


}

/// @nodoc
abstract mixin class _$ReferralStatsCopyWith<$Res> implements $ReferralStatsCopyWith<$Res> {
  factory _$ReferralStatsCopyWith(_ReferralStats value, $Res Function(_ReferralStats) _then) = __$ReferralStatsCopyWithImpl;
@override @useResult
$Res call({
 String referralCode, String referralLink, int rewardAmount, int referralLimit, int remainingReferrals, int referralCount, int totalReferralEarnings, int totalInvited, int creditedCount, int pendingCount, int rejectedCount, String rewardCondition, List<InvitedPartner> invitedPartners
});




}
/// @nodoc
class __$ReferralStatsCopyWithImpl<$Res>
    implements _$ReferralStatsCopyWith<$Res> {
  __$ReferralStatsCopyWithImpl(this._self, this._then);

  final _ReferralStats _self;
  final $Res Function(_ReferralStats) _then;

/// Create a copy of ReferralStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? referralCode = null,Object? referralLink = null,Object? rewardAmount = null,Object? referralLimit = null,Object? remainingReferrals = null,Object? referralCount = null,Object? totalReferralEarnings = null,Object? totalInvited = null,Object? creditedCount = null,Object? pendingCount = null,Object? rejectedCount = null,Object? rewardCondition = null,Object? invitedPartners = null,}) {
  return _then(_ReferralStats(
referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referralLink: null == referralLink ? _self.referralLink : referralLink // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as int,referralLimit: null == referralLimit ? _self.referralLimit : referralLimit // ignore: cast_nullable_to_non_nullable
as int,remainingReferrals: null == remainingReferrals ? _self.remainingReferrals : remainingReferrals // ignore: cast_nullable_to_non_nullable
as int,referralCount: null == referralCount ? _self.referralCount : referralCount // ignore: cast_nullable_to_non_nullable
as int,totalReferralEarnings: null == totalReferralEarnings ? _self.totalReferralEarnings : totalReferralEarnings // ignore: cast_nullable_to_non_nullable
as int,totalInvited: null == totalInvited ? _self.totalInvited : totalInvited // ignore: cast_nullable_to_non_nullable
as int,creditedCount: null == creditedCount ? _self.creditedCount : creditedCount // ignore: cast_nullable_to_non_nullable
as int,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,rejectedCount: null == rejectedCount ? _self.rejectedCount : rejectedCount // ignore: cast_nullable_to_non_nullable
as int,rewardCondition: null == rewardCondition ? _self.rewardCondition : rewardCondition // ignore: cast_nullable_to_non_nullable
as String,invitedPartners: null == invitedPartners ? _self._invitedPartners : invitedPartners // ignore: cast_nullable_to_non_nullable
as List<InvitedPartner>,
  ));
}


}


/// @nodoc
mixin _$InvitedPartner {

 String get id; String get name; String get phone; String get partnerStatus; int get deliveriesCompleted; String get status; String get reason; int get rewardAmount; int get earnedAmount; String get invitedAt;
/// Create a copy of InvitedPartner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvitedPartnerCopyWith<InvitedPartner> get copyWith => _$InvitedPartnerCopyWithImpl<InvitedPartner>(this as InvitedPartner, _$identity);

  /// Serializes this InvitedPartner to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvitedPartner&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.partnerStatus, partnerStatus) || other.partnerStatus == partnerStatus)&&(identical(other.deliveriesCompleted, deliveriesCompleted) || other.deliveriesCompleted == deliveriesCompleted)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.earnedAmount, earnedAmount) || other.earnedAmount == earnedAmount)&&(identical(other.invitedAt, invitedAt) || other.invitedAt == invitedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,phone,partnerStatus,deliveriesCompleted,status,reason,rewardAmount,earnedAmount,invitedAt);

@override
String toString() {
  return 'InvitedPartner(id: $id, name: $name, phone: $phone, partnerStatus: $partnerStatus, deliveriesCompleted: $deliveriesCompleted, status: $status, reason: $reason, rewardAmount: $rewardAmount, earnedAmount: $earnedAmount, invitedAt: $invitedAt)';
}


}

/// @nodoc
abstract mixin class $InvitedPartnerCopyWith<$Res>  {
  factory $InvitedPartnerCopyWith(InvitedPartner value, $Res Function(InvitedPartner) _then) = _$InvitedPartnerCopyWithImpl;
@useResult
$Res call({
 String id, String name, String phone, String partnerStatus, int deliveriesCompleted, String status, String reason, int rewardAmount, int earnedAmount, String invitedAt
});




}
/// @nodoc
class _$InvitedPartnerCopyWithImpl<$Res>
    implements $InvitedPartnerCopyWith<$Res> {
  _$InvitedPartnerCopyWithImpl(this._self, this._then);

  final InvitedPartner _self;
  final $Res Function(InvitedPartner) _then;

/// Create a copy of InvitedPartner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? phone = null,Object? partnerStatus = null,Object? deliveriesCompleted = null,Object? status = null,Object? reason = null,Object? rewardAmount = null,Object? earnedAmount = null,Object? invitedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,partnerStatus: null == partnerStatus ? _self.partnerStatus : partnerStatus // ignore: cast_nullable_to_non_nullable
as String,deliveriesCompleted: null == deliveriesCompleted ? _self.deliveriesCompleted : deliveriesCompleted // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as int,earnedAmount: null == earnedAmount ? _self.earnedAmount : earnedAmount // ignore: cast_nullable_to_non_nullable
as int,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvitedPartner].
extension InvitedPartnerPatterns on InvitedPartner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvitedPartner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvitedPartner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvitedPartner value)  $default,){
final _that = this;
switch (_that) {
case _InvitedPartner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvitedPartner value)?  $default,){
final _that = this;
switch (_that) {
case _InvitedPartner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String phone,  String partnerStatus,  int deliveriesCompleted,  String status,  String reason,  int rewardAmount,  int earnedAmount,  String invitedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvitedPartner() when $default != null:
return $default(_that.id,_that.name,_that.phone,_that.partnerStatus,_that.deliveriesCompleted,_that.status,_that.reason,_that.rewardAmount,_that.earnedAmount,_that.invitedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String phone,  String partnerStatus,  int deliveriesCompleted,  String status,  String reason,  int rewardAmount,  int earnedAmount,  String invitedAt)  $default,) {final _that = this;
switch (_that) {
case _InvitedPartner():
return $default(_that.id,_that.name,_that.phone,_that.partnerStatus,_that.deliveriesCompleted,_that.status,_that.reason,_that.rewardAmount,_that.earnedAmount,_that.invitedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String phone,  String partnerStatus,  int deliveriesCompleted,  String status,  String reason,  int rewardAmount,  int earnedAmount,  String invitedAt)?  $default,) {final _that = this;
switch (_that) {
case _InvitedPartner() when $default != null:
return $default(_that.id,_that.name,_that.phone,_that.partnerStatus,_that.deliveriesCompleted,_that.status,_that.reason,_that.rewardAmount,_that.earnedAmount,_that.invitedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvitedPartner implements InvitedPartner {
  const _InvitedPartner({this.id = '', this.name = '', this.phone = '', this.partnerStatus = '', this.deliveriesCompleted = 0, this.status = '', this.reason = '', this.rewardAmount = 0, this.earnedAmount = 0, this.invitedAt = ''});
  factory _InvitedPartner.fromJson(Map<String, dynamic> json) => _$InvitedPartnerFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String partnerStatus;
@override@JsonKey() final  int deliveriesCompleted;
@override@JsonKey() final  String status;
@override@JsonKey() final  String reason;
@override@JsonKey() final  int rewardAmount;
@override@JsonKey() final  int earnedAmount;
@override@JsonKey() final  String invitedAt;

/// Create a copy of InvitedPartner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvitedPartnerCopyWith<_InvitedPartner> get copyWith => __$InvitedPartnerCopyWithImpl<_InvitedPartner>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvitedPartnerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvitedPartner&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.partnerStatus, partnerStatus) || other.partnerStatus == partnerStatus)&&(identical(other.deliveriesCompleted, deliveriesCompleted) || other.deliveriesCompleted == deliveriesCompleted)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.earnedAmount, earnedAmount) || other.earnedAmount == earnedAmount)&&(identical(other.invitedAt, invitedAt) || other.invitedAt == invitedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,phone,partnerStatus,deliveriesCompleted,status,reason,rewardAmount,earnedAmount,invitedAt);

@override
String toString() {
  return 'InvitedPartner(id: $id, name: $name, phone: $phone, partnerStatus: $partnerStatus, deliveriesCompleted: $deliveriesCompleted, status: $status, reason: $reason, rewardAmount: $rewardAmount, earnedAmount: $earnedAmount, invitedAt: $invitedAt)';
}


}

/// @nodoc
abstract mixin class _$InvitedPartnerCopyWith<$Res> implements $InvitedPartnerCopyWith<$Res> {
  factory _$InvitedPartnerCopyWith(_InvitedPartner value, $Res Function(_InvitedPartner) _then) = __$InvitedPartnerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String phone, String partnerStatus, int deliveriesCompleted, String status, String reason, int rewardAmount, int earnedAmount, String invitedAt
});




}
/// @nodoc
class __$InvitedPartnerCopyWithImpl<$Res>
    implements _$InvitedPartnerCopyWith<$Res> {
  __$InvitedPartnerCopyWithImpl(this._self, this._then);

  final _InvitedPartner _self;
  final $Res Function(_InvitedPartner) _then;

/// Create a copy of InvitedPartner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? phone = null,Object? partnerStatus = null,Object? deliveriesCompleted = null,Object? status = null,Object? reason = null,Object? rewardAmount = null,Object? earnedAmount = null,Object? invitedAt = null,}) {
  return _then(_InvitedPartner(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,partnerStatus: null == partnerStatus ? _self.partnerStatus : partnerStatus // ignore: cast_nullable_to_non_nullable
as String,deliveriesCompleted: null == deliveriesCompleted ? _self.deliveriesCompleted : deliveriesCompleted // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as int,earnedAmount: null == earnedAmount ? _self.earnedAmount : earnedAmount // ignore: cast_nullable_to_non_nullable
as int,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
