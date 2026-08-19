// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReferralStats _$ReferralStatsFromJson(Map<String, dynamic> json) =>
    _ReferralStats(
      referralCode: json['referralCode'] as String? ?? '',
      referralLink: json['referralLink'] as String? ?? '',
      rewardAmount: (json['rewardAmount'] as num?)?.toInt() ?? 0,
      referralLimit: (json['referralLimit'] as num?)?.toInt() ?? 0,
      remainingReferrals: (json['remainingReferrals'] as num?)?.toInt() ?? 0,
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      totalReferralEarnings:
          (json['totalReferralEarnings'] as num?)?.toInt() ?? 0,
      totalInvited: (json['totalInvited'] as num?)?.toInt() ?? 0,
      creditedCount: (json['creditedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      rejectedCount: (json['rejectedCount'] as num?)?.toInt() ?? 0,
      rewardCondition: json['rewardCondition'] as String? ?? '',
      invitedPartners:
          (json['invitedPartners'] as List<dynamic>?)
              ?.map((e) => InvitedPartner.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReferralStatsToJson(_ReferralStats instance) =>
    <String, dynamic>{
      'referralCode': instance.referralCode,
      'referralLink': instance.referralLink,
      'rewardAmount': instance.rewardAmount,
      'referralLimit': instance.referralLimit,
      'remainingReferrals': instance.remainingReferrals,
      'referralCount': instance.referralCount,
      'totalReferralEarnings': instance.totalReferralEarnings,
      'totalInvited': instance.totalInvited,
      'creditedCount': instance.creditedCount,
      'pendingCount': instance.pendingCount,
      'rejectedCount': instance.rejectedCount,
      'rewardCondition': instance.rewardCondition,
      'invitedPartners': instance.invitedPartners,
    };

_InvitedPartner _$InvitedPartnerFromJson(Map<String, dynamic> json) =>
    _InvitedPartner(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      partnerStatus: json['partnerStatus'] as String? ?? '',
      deliveriesCompleted: (json['deliveriesCompleted'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      rewardAmount: (json['rewardAmount'] as num?)?.toInt() ?? 0,
      earnedAmount: (json['earnedAmount'] as num?)?.toInt() ?? 0,
      invitedAt: json['invitedAt'] as String? ?? '',
    );

Map<String, dynamic> _$InvitedPartnerToJson(_InvitedPartner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'partnerStatus': instance.partnerStatus,
      'deliveriesCompleted': instance.deliveriesCompleted,
      'status': instance.status,
      'reason': instance.reason,
      'rewardAmount': instance.rewardAmount,
      'earnedAmount': instance.earnedAmount,
      'invitedAt': instance.invitedAt,
    };
