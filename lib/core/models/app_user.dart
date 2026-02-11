import '../utils/firestore_helpers.dart';
import 'stats_summary.dart';
import 'user_membership.dart';
import 'validator_stats.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String username;
  final String usernameLower;
  final String avatarUrl;
  final String email;
  final String bio;
  final String country;
  final List<String> sessions;
  final List<String> instruments;
  final String strategyStyle;
  final String experienceLevel;
  final String role;
  final String traderStatus;
  final String? rejectReason;
  final String? bannerUrl;
  final String? bannerPath;
  final DateTime? bannerUpdatedAt;
  final Map<String, String> socials;
  final Map<String, String> socialLinks;
  final int? yearsExperience;
  final bool? onboardingCompleted;
  final int? onboardingStep;
  final List<String>? interests;
  final Map<String, bool>? nudgeFlags;
  final bool? notifyNewSignals;
  final bool? notifSignals;
  final bool? notifAnnouncements;
  final String? phoneNumber;
  final UserMembership? membership;
  final bool? termsAccepted;
  final DateTime? termsAcceptedAt;
  final String? termsVersion;
  final String? termsAcceptedAppVersion;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final StatsSummary statsSummary;
  final ValidatorStats validatorStats;
  final int followerCount;
  final int followingCount;
  final bool isBanned;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.usernameLower,
    required this.avatarUrl,
    required this.email,
    required this.bio,
    required this.country,
    required this.sessions,
    required this.instruments,
    required this.strategyStyle,
    required this.experienceLevel,
    required this.role,
    required this.traderStatus,
    this.rejectReason,
    this.bannerUrl,
    this.bannerPath,
    this.bannerUpdatedAt,
    required this.socials,
    required this.socialLinks,
    this.yearsExperience,
    this.onboardingCompleted,
    this.onboardingStep,
    this.interests,
    this.nudgeFlags,
    this.notifyNewSignals,
    this.notifSignals,
    this.notifAnnouncements,
    this.phoneNumber,
    this.membership,
    this.termsAccepted,
    this.termsAcceptedAt,
    this.termsVersion,
    this.termsAcceptedAppVersion,
    required this.isVerified,
    this.verifiedAt,
    required this.createdAt,
    this.updatedAt,
    required this.statsSummary,
    required this.validatorStats,
    required this.followerCount,
    required this.followingCount,
    required this.isBanned,
  });

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) {
    return AppUser(
      uid: uid,
      displayName: json['displayName'] ?? '',
      username: json['username'] ?? '',
      usernameLower: json['usernameLower'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      email: json['email'] ?? '',
      bio: json['bio'] ?? '',
      country: json['country'] ?? '',
      sessions: List<String>.from(json['sessions'] ?? const <String>[]),
      instruments:
          List<String>.from(json['instruments'] ?? const <String>[]),
      strategyStyle: json['strategyStyle'] ?? '',
      experienceLevel: json['experienceLevel'] ?? '',
      role: (json['role'] as String?)?.toLowerCase() ?? 'member',
      traderStatus: json['traderStatus'] ?? 'none',
      rejectReason: json['rejectReason'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bannerPath: json['bannerPath'] as String?,
      bannerUpdatedAt: timestampToDate(json['bannerUpdatedAt']),
      socials: {
        if (json['socials'] != null)
          ...Map<String, dynamic>.from(json['socials'])
              .map((key, value) => MapEntry(key, '$value')),
      },
      socialLinks: _stringMap(json['socialLinks']),
      yearsExperience: (json['yearsExperience'] != null)
          ? (json['yearsExperience'] as num).toInt()
          : null,
      onboardingCompleted: json['onboardingCompleted'] as bool?,
      onboardingStep: (json['onboardingStep'] as num?)?.toInt(),
      interests: json['interests'] != null
          ? List<String>.from(json['interests'])
          : null,
      nudgeFlags: json['nudgeFlags'] != null
          ? Map<String, dynamic>.from(json['nudgeFlags'])
              .map((key, value) => MapEntry(key, value == true))
          : null,
      notifyNewSignals: json['notifyNewSignals'] as bool?,
      notifSignals: json['notifSignals'] as bool?,
      notifAnnouncements: json['notifAnnouncements'] as bool?,
      phoneNumber: json['phoneNumber'] as String?,
      membership: UserMembership.fromJson(
        json['membership'] as Map<String, dynamic>?,
      ),
      termsAccepted: json['termsAccepted'] as bool?,
      termsAcceptedAt: timestampToDate(json['termsAcceptedAt']),
      termsVersion: json['termsVersion'] as String?,
      termsAcceptedAppVersion: json['termsAcceptedAppVersion'] as String?,
      isVerified: json['isVerified'] ?? false,
      verifiedAt: timestampToDate(json['verifiedAt']),
      createdAt: timestampToDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: timestampToDate(json['updatedAt']),
      statsSummary:
          StatsSummary.fromJson(json['statsSummary'] as Map<String, dynamic>?),
      validatorStats: ValidatorStats.fromJson(
        json['validatorStats'] as Map<String, dynamic>?,
      ),
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isBanned: json['isBanned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'usernameLower': usernameLower,
      'avatarUrl': avatarUrl,
      if (email.isNotEmpty) 'email': email,
      'bio': bio,
      'country': country,
      'sessions': sessions,
      'instruments': instruments,
      'strategyStyle': strategyStyle,
      'experienceLevel': experienceLevel,
      'role': role.toLowerCase(),
      'traderStatus': traderStatus,
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
      if (bannerPath != null) 'bannerPath': bannerPath,
      if (bannerUpdatedAt != null)
        'bannerUpdatedAt': dateToTimestamp(bannerUpdatedAt),
      'socials': socials,
      'socialLinks': socialLinks,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
      if (onboardingCompleted != null)
        'onboardingCompleted': onboardingCompleted,
      if (onboardingStep != null) 'onboardingStep': onboardingStep,
      if (interests != null) 'interests': interests,
      if (nudgeFlags != null) 'nudgeFlags': nudgeFlags,
      if (notifyNewSignals != null) 'notifyNewSignals': notifyNewSignals,
      if (notifSignals != null) 'notifSignals': notifSignals,
      if (notifAnnouncements != null)
        'notifAnnouncements': notifAnnouncements,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (membership != null) 'membership': membership!.toJson(),
      if (termsAccepted != null) 'termsAccepted': termsAccepted,
      if (termsAcceptedAt != null)
        'termsAcceptedAt': dateToTimestamp(termsAcceptedAt),
      if (termsVersion != null) 'termsVersion': termsVersion,
      if (termsAcceptedAppVersion != null)
        'termsAcceptedAppVersion': termsAcceptedAppVersion,
      'isVerified': isVerified,
      'verifiedAt': dateToTimestamp(verifiedAt),
      'createdAt': dateToTimestamp(createdAt),
      if (updatedAt != null) 'updatedAt': dateToTimestamp(updatedAt),
      'statsSummary': statsSummary.toJson(),
      'validatorStats': validatorStats.toJson(),
      'followerCount': followerCount,
      'followingCount': followingCount,
      'isBanned': isBanned,
    };
  }

  factory AppUser.placeholder(String uid) {
    return AppUser(
      uid: uid,
      displayName: '',
      username: '',
      usernameLower: '',
      avatarUrl: '',
      email: '',
      bio: '',
      country: '',
      sessions: const [],
      instruments: const [],
      strategyStyle: '',
      experienceLevel: '',
      role: 'member',
      traderStatus: 'none',
      rejectReason: null,
      bannerUrl: null,
      bannerPath: null,
      bannerUpdatedAt: null,
      socials: const {},
      socialLinks: const {},
      yearsExperience: null,
      onboardingCompleted: null,
      onboardingStep: null,
      interests: null,
      nudgeFlags: null,
      notifyNewSignals: null,
      phoneNumber: null,
      membership: UserMembership.free(),
      termsAccepted: null,
      termsAcceptedAt: null,
      termsVersion: null,
      termsAcceptedAppVersion: null,
      isVerified: false,
      verifiedAt: null,
      createdAt: DateTime.now(),
      updatedAt: null,
      statsSummary: StatsSummary.empty(),
      validatorStats: ValidatorStats.empty(),
      followerCount: 0,
      followingCount: 0,
      isBanned: false,
    );
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value == null) {
    return const {};
  }
  return Map<String, dynamic>.from(value as Map).map(
    (key, val) => MapEntry(key.toString(), '${val ?? ''}'),
  );
}
