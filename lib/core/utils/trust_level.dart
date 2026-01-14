import 'dart:math';

import '../models/app_user.dart';

const int trustLevelNew = 0;
const int trustLevelBasic = 1;
const int trustLevelTrusted = 2;

const int _minAgeBasicDays = 7;
const int _minAgeTrustedDays = 30;
const int _minFollowerCount = 10;
const int _minAccuracyVotes = 5;
const double _minAccuracy = 0.6;
const int _basicScoreThreshold = 3;
const int _trustedScoreThreshold = 5;

int computeTrustLevel(AppUser user) {
  final ageDays = DateTime.now().difference(user.createdAt).inDays;
  final emailVerified = user.isVerified;
  final profileComplete = _isProfileComplete(user);
  final followCount = max(user.followerCount, user.followingCount);
  final accuracy = user.validatorStats.accuracy;
  final hasAccuracy = user.validatorStats.totalVotes >= _minAccuracyVotes &&
      accuracy >= _minAccuracy;

  var score = 0;
  if (ageDays >= _minAgeTrustedDays) {
    score += 2;
  } else if (ageDays >= _minAgeBasicDays) {
    score += 1;
  }
  if (emailVerified) {
    score += 1;
  }
  if (profileComplete) {
    score += 1;
  }
  if (followCount >= _minFollowerCount) {
    score += 1;
  }
  if (hasAccuracy) {
    score += 1;
  }

  if (score >= _trustedScoreThreshold) {
    return trustLevelTrusted;
  }
  if (score >= _basicScoreThreshold) {
    return trustLevelBasic;
  }
  return trustLevelNew;
}

double weightForTrustLevel(int trustLevel) {
  switch (trustLevel) {
    case trustLevelTrusted:
      return 2.0;
    case trustLevelBasic:
      return 1.0;
    default:
      return 0.2;
  }
}

String trustLabel(int trustLevel) {
  switch (trustLevel) {
    case trustLevelTrusted:
      return 'Trusted';
    case trustLevelBasic:
      return 'Basic';
    default:
      return 'New';
  }
}

bool _isProfileComplete(AppUser user) {
  return user.displayName.isNotEmpty &&
      user.username.isNotEmpty &&
      user.bio.isNotEmpty &&
      user.country.isNotEmpty &&
      user.sessions.isNotEmpty &&
      user.instruments.isNotEmpty &&
      user.strategyStyle.isNotEmpty &&
      user.experienceLevel.isNotEmpty;
}
