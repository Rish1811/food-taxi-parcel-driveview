import 'package:freezed_annotation/freezed_annotation.dart';

part 'referral_stats.freezed.dart';
part 'referral_stats.g.dart';

@freezed
abstract class ReferralStats with _$ReferralStats {
  const factory ReferralStats({
    @Default('') String referralCode,
    @Default('') String referralLink,
    @Default(0) int rewardAmount,
    @Default(0) int referralLimit,
    @Default(0) int remainingReferrals,
    @Default(0) int referralCount,
    @Default(0) int totalReferralEarnings,
    @Default(0) int totalInvited,
    @Default(0) int creditedCount,
    @Default(0) int pendingCount,
    @Default(0) int rejectedCount,
    @Default('') String rewardCondition,
    @Default([]) List<InvitedPartner> invitedPartners,
  }) = _ReferralStats;

  factory ReferralStats.fromJson(Map<String, dynamic> json) =>
      _$ReferralStatsFromJson(json);
}

@freezed
abstract class InvitedPartner with _$InvitedPartner {
  const factory InvitedPartner({
    @Default('') String id,
    @Default('') String name,
    @Default('') String phone,
    @Default('') String partnerStatus, // pending|approved|rejected
    @Default(0) int deliveriesCompleted,
    @Default('') String status, // credited|pending|rejected
    @Default('') String reason,
    @Default(0) int rewardAmount,
    @Default(0) int earnedAmount,
    @Default('') String invitedAt,
  }) = _InvitedPartner;

  factory InvitedPartner.fromJson(Map<String, dynamic> json) =>
      _$InvitedPartnerFromJson(json);
}
